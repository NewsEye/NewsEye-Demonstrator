puts "seeding..."

json_data = JSON.parse(File.read(File.join(File.dirname(__FILE__), '../db/seeds_data/data.json')))

json_data.each do |newspaper|
  newspaper = newspaper.with_indifferent_access
  npid = newspaper[:title].to_ascii.sub(' ', '_')
  if Newspaper.exists?(npid)
    puts "newspaper %s already exists" % newspaper[:title]
    np = Newspaper.find(npid)
  else
    puts "adding newspaper %s" % newspaper[:title]
    np = Newspaper.new
    np.id = npid
    np.title = newspaper[:title]
    np.publisher = newspaper[:publisher]
    np.language = newspaper[:language]
    np.datefrom = newspaper[:datefrom]
    np.dateto = newspaper[:dateto]
    np.location = newspaper[:location]
    np.save
  end
  newspaper[:issues].each do |np_issue|
    issueid = np.id + '_' + np_issue[:id]
    should_process = false
    if Issue.exists?(issueid)
      issue = Issue.find(issueid)
      if issue.all_text.nil?
        should_process = true
      else
        puts " issue %s already exists" % np_issue[:id]
      end
    else
      issue = Issue.new
      issue.id = issueid
      should_process = true
    end
    if should_process
      puts " adding issue %s" % np_issue[:id]
      issue.original_uri = np_issue[:original_uri]
      issue.publisher = np_issue[:publisher]
      issue.title = np_issue[:title]
      issue.date_created = np_issue[:date_created]
      issue.nb_pages = np_issue[:nb_pages]
      issue.language = np_issue[:language]
      issue.save
      issue_ocr_text = ''

      nb_workers = 4
      work_q = Queue.new
      np_issue[:pages].each do |issue_page|
        work_q << [issue_page, issue]
      end
      master_reader, master_writer = IO.pipe
      slave_writers = []
      workers = (0...nb_workers).map do |i|
        slave_reader, slave_writer = IO.pipe
        slave_writers << slave_writer
        Thread.new do
          Rails.application.reloader.wrap do
            begin
              while work_q.size != 0
                (issue_page, issue) = work_q.pop(true)
                begin
                  work(np_issue, issue_page, issue)
                rescue Exception => e
                  puts "Error creating pagefileset"
                  puts e.inspect
                end
              end
            rescue ThreadError => te
              puts "error in thread #{i}"
              puts te.inspect
            end
          end
        end
      end
      workers.each do |worker|
        worker.join
        pfs = worker[:output_pfs]
        ocr_full_text = worker[:output_fulltext]
        pfs.save
        issue.ordered_members << pfs
        pfs.save
        issue.save
        issue_ocr_text += ocr_full_text
      end
      issue.all_text = issue_ocr_text
      np.members << issue
      issue.member_of_collections << np
      issue.save
      np.save
      SolrService.commit  # commit annotations
    end
  end  # Issue is processed
end

BEGIN {
  def work(np_issue, issue_page, issue)
    puts "  adding page %i out of %i" % [issue_page[:page_number], np_issue[:pages].length]

    pfs = PageFileSet.new
    pfs.id = issue.id + '_' + issue_page[:id].split('_')[1..-1].join('_')
    pfs.page_number = issue_page[:page_number]

    if issue.original_uri.include? 'ark:/' # If there exists an iiif image service
      pfs.iiif_url = (issue.original_uri + "/f#{pfs.page_number}").insert(issue.original_uri.index('ark:/'), 'iiif/')
      info_json = JSON.load(open(pfs.iiif_url+'/info.json'))
      pfs.height = info_json['height'].to_i
      pfs.width = info_json['width'].to_i
      pfs.mime_type = 'image/jpeg'
      if issue_page[:page_number] == 1
        issue.thumbnail_url = "#{pfs.iiif_url}/full/,200/0/default.jpg"
      end
    else # Else import image
      open(Rails.root.to_s + issue_page[:image_path], 'r') do |image_full|
        Hydra::Works::AddFileToFileSet.call(pfs, image_full, :original_file)
      end
      Hydra::Works::CharacterizationService.run pfs.original_file
      pfs.height = pfs.original_file.height.first
      pfs.width = pfs.original_file.width.first
      pfs.mime_type = pfs.original_file.mime_type
      if issue_page[:page_number] == 1
        issue.thumbnail_url = "#{Rails.configuration.newseye_services['host']}/iiif/#{issue.id}_page_1/full/,200/0/default.jpg"
      end
    end

    ###### Parse OCR and add full text property ######

    encoding = CharlockHolmes::EncodingDetector.detect(File.read(Rails.root.to_s + issue_page[:ocr_path]))[:ruby_encoding]
    ocr_file = open(Rails.root.to_s + issue_page[:ocr_path], 'r')
    Hydra::Works::AddFileToFileSet.call(pfs, ocr_file, :alto_xml)
    ocr = File.open(Rails.root.to_s + issue_page[:ocr_path]) do |f|
      Nokogiri::XML(f, nil, encoding)
    end
    ocr.remove_namespaces!

    ###### IIIF Annotation generation ######

    scale_factor = pfs.height.to_f / ocr.xpath('//Page')[0]['HEIGHT'].to_f
    ocr_full_text, block_annots, line_annots, word_annots = parse_alto_index(ocr, issue.id, pfs.page_number, scale_factor)

    annotation_file = Tempfile.new(%w(annotation_list_word_level .json), Rails.root.to_s + '/tmp', encoding: 'UTF-8')
    annotation_file.write(word_annots)
    annotation_file.close
    annotation_file = open(annotation_file.path, 'r')
    Hydra::Works::AddFileToFileSet.call(pfs, annotation_file, :ocr_word_level_annotation_list)

    annotation_file = Tempfile.new(%w(annotation_list_line_level .json), Rails.root.to_s + '/tmp', encoding: 'UTF-8')
    annotation_file.write(line_annots)
    annotation_file.close
    annotation_file = open(annotation_file.path, 'r')
    Hydra::Works::AddFileToFileSet.call(pfs, annotation_file, :ocr_line_level_annotation_list)

    annotation_file = Tempfile.new(%w(annotation_list_block_level .json), Rails.root.to_s + '/tmp', encoding: 'UTF-8')
    annotation_file.write(block_annots)
    annotation_file.close
    annotation_file = open(annotation_file.path, 'r')
    Hydra::Works::AddFileToFileSet.call(pfs, annotation_file, :ocr_block_level_annotation_list)

    Thread.current[:output_pfs] = pfs
    Thread.current[:output_fulltext] = ocr_full_text
  end

  def parse_alto_index(doc, doc_id, page_num, scale_factor, generate_neo4j=false)
    # neo4j_page = ["CREATE (p#{page_num}:Page {label:\"#{doc_id}_#{page_num}\", target:\"#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/canvas/page_#{page_num}\"})"]
    page_ocr_text = ''
    block_annotation_list = {}
    block_annotation_list['@context'] = 'http://iiif.io/api/presentation/2/context.json'
    block_annotation_list['@id'] = "/iiif/#{doc_id}/list/page_#{page_num}_ocr_block_level"
    block_annotation_list['@type'] = 'sc:AnnotationList'
    block_annotation_list['resources'] = []
    block_annotation_list['within'] = {}
    block_annotation_list['within']['@id'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/layer/ocr_block_level"
    block_annotation_list['within']['@type'] = 'sc:Layer'
    block_annotation_list['within']['label'] = 'OCR Layer'
    word_annotation_list = {}
    word_annotation_list['@context'] = 'http://iiif.io/api/presentation/2/context.json'
    word_annotation_list['@id'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/list/page_#{page_num}_ocr_word_level"
    word_annotation_list['@type'] = 'sc:AnnotationList'
    word_annotation_list['resources'] = []
    word_annotation_list['within'] = {}
    word_annotation_list['within']['@id'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/layer/ocr_word_level"
    word_annotation_list['within']['@type'] = 'sc:Layer'
    word_annotation_list['within']['label'] = 'OCR Layer'
    line_annotation_list = {}
    line_annotation_list['@context'] = 'http://iiif.io/api/presentation/2/context.json'
    line_annotation_list['@id']#{Rails.configuration.newseye_services['host']} = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/list/page_#{page_num}_ocr_line_level"
    line_annotation_list['@type'] = 'sc:AnnotationList'
    line_annotation_list['resources'] = []
    line_annotation_list['within'] = {}
    line_annotation_list['within']['@id'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/layer/ocr_line_level"
    line_annotation_list['within']['@type'] = 'sc:Layer'
    line_annotation_list['within']['label'] = 'OCR Layer'

    nb_blocks = doc.xpath('//TextBlock').size
    in_page_word_index = 0
    in_page_line_index = 0
    # neo4j_blocks = []
    doc.xpath('//TextBlock').each_with_index do |block, block_index|
      print "  block #{block_index+1} out of #{nb_blocks}\r"
      block_id = "#{doc_id}_#{page_num}_block_#{block_index}"
      block_text = []
      block_confidence = 0
      nb_lines = block.children.select{|line| line.name == 'TextLine'}.size
      # neo4j_lines = []
      in_block_word_index = 0
      block.children.select{|line| line.name == 'TextLine'}.each_with_index do |line, in_block_line_index|
        line_index = in_page_line_index + in_block_line_index
        line_id = "#{doc_id}_#{page_num}_line_#{line_index}"
        line_text = []
        line_confidence = 0
        nb_words = line.children.select{|str| str.name == 'String'}.size
        # neo4j_words = []
        line.children.select{|str| str.name == 'String'}.each_with_index do |word, in_line_word_index|
          word_index = in_page_word_index + in_line_word_index
          word_id = "#{doc_id}_#{page_num}_word_#{word_index}"
          str_content = word['CONTENT']
          page_ocr_text += word['CONTENT'] + ' '
          word_annot = {}
          word_annot['@type'] = 'oa:Annotation'
          word_annot['motivation'] = 'sc:painting'
          word_annot['resource'] = {}
          word_annot['resource']['@type'] = 'cnt:ContentAsText'
          word_annot['resource']['format'] = 'text/plain'
          word_annot['resource']['chars'] = str_content
          word_annot['metadata'] = {}
          word_annot['metadata']['word_confidence'] = word['WC'].to_f
          word_selector = <<~HEREDOC.gsub(/^[\s\t]*|[\s\t]*\n/, '')
            #xywh=
            #{(word['HPOS'].to_i*scale_factor).to_i},
            #{(word['VPOS'].to_i*scale_factor).to_i},
            #{(word['WIDTH'].to_i*scale_factor).to_i},
            #{(word['HEIGHT'].to_i*scale_factor).to_i}
          HEREDOC
          word_annot['on'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/canvas/page_#{page_num}#{word_selector}"
          word_annotation_list['resources'] << word_annot

          # neo4j_words.push("CREATE (w#{word_index}:Word {id:\"#{word_id}\", content:\"#{str_content.gsub(/"/,'\\"')}\", selector:\"#{word_selector}\"})")
          # neo4j_words.push("CREATE (w#{word_index})-[:IN_LINE {index:#{in_line_word_index}}]->(l#{line_index})")
          # neo4j_words.push("CREATE (w#{word_index})-[:IN_BLOCK {index:#{in_block_word_index}}]->(b#{block_index})")
          # neo4j_words.push("CREATE (w#{word_index})-[:IN_PAGE {index:#{in_page_word_index}}]->(p#{page_num})")

          word_data = {
              id: word_id,
              target: word_annot['on'][0..word_annot['on'].index('#')-1],
              selector: word_annot['on'][word_annot['on'].index('#')..-1],
              level: "word",
              level_reading_order: word_index,
              parent_line_id: line_id,
              parent_block_id: block_id,
              body: "<p>#{str_content}</p>"
          }
          SolrService.add word_data
          line_text << str_content
          line_confidence += word['WC'].to_f
          block_text << str_content
          block_confidence += word['WC'].to_f
        end
        in_page_word_index += nb_words
        in_block_word_index += nb_words
        page_ocr_text.strip!
        page_ocr_text += "\n"
        line_annot = {}
        line_annot['@type'] = 'oa:Annotation'
        line_annot['motivation'] = 'sc:painting'
        line_annot['resource'] = {}
        line_annot['resource']['@type'] = 'cnt:ContentAsText'
        line_annot['resource']['format'] = 'text/plain'
        line_annot['resource']['chars'] = line_text.join(' ')
        line_annot['metadata'] = {}
        line_annot['metadata']['word_confidence'] = line_text.size == 0 ? 0 : line_confidence / line_text.size
        line_selector = <<~HEREDOC.gsub(/^[\s\t]*|[\s\t]*\n/, '')
          #xywh=
          #{(line['HPOS'].to_i*scale_factor).to_i},
          #{(line['VPOS'].to_i*scale_factor).to_i},
          #{(line['WIDTH'].to_i*scale_factor).to_i},
          #{(line['HEIGHT'].to_i*scale_factor).to_i}
        HEREDOC
        line_annot['on'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/canvas/page_#{page_num}#{line_selector}"
        line_annotation_list['resources'] << line_annot

        # neo4j_lines.push("CREATE (l#{line_index}:Line {id:\"#{line_id}\", content:\"#{line_text.join(' ').gsub(/"/,'\\"')}\", selector:\"#{line_selector}\"})")
        # neo4j_lines.push("CREATE (l#{line_index})-[:IN_BLOCK {index:#{in_block_line_index}}]->(b#{block_index})")
        # neo4j_lines.push("CREATE (l#{line_index})-[:IN_PAGE {index:#{in_page_line_index}}]->(p#{page_num})")
        # neo4j_lines.concat neo4j_words

        line_data = {
            id: line_id,
            target: line_annot['on'][0..line_annot['on'].index('#')-1],
            selector: line_annot['on'][line_annot['on'].index('#')..-1],
            level: "line",
            level_reading_order: line_index,
            parent_block_id: block_id,
            body: "<p>#{line_text.join(' ')}</p>"
        }
        SolrService.add line_data
      end
      in_page_line_index += nb_lines
      page_ocr_text.strip!
      block_annot = {}
      block_annot['@type'] = 'oa:Annotation'
      block_annot['motivation'] = 'sc:painting'
      block_annot['resource'] = {}
      block_annot['resource']['@type'] = 'cnt:ContentAsText'
      block_annot['resource']['format'] = 'text/plain'
      block_annot['resource']['chars'] = block_text.join(' ')
      block_annot['metadata'] = {}
      block_annot['metadata'] = {}
      block_annot['metadata']['word_confidence'] = block_text.size == 0 ? 0 : block_confidence / block_text.size
      block_selector = <<~HEREDOC.gsub(/^[\s\t]*|[\s\t]*\n/, '')
        #xywh=
        #{(block['HPOS'].to_i*scale_factor).to_i},
        #{(block['VPOS'].to_i*scale_factor).to_i},
        #{(block['WIDTH'].to_i*scale_factor).to_i},
        #{(block['HEIGHT'].to_i*scale_factor).to_i}
      HEREDOC
      block_annot['on'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/canvas/page_#{page_num}#{block_selector}"
      block_annotation_list['resources'] << block_annot

      # neo4j_blocks.push("CREATE (b#{block_index}:Block {id:\"#{block_id}\", content:\"#{block_text.join(' ').gsub(/"/,'\\"')}\", selector:\"#{block_selector}\"})")
      # neo4j_blocks.push("CREATE (b#{block_index})-[:IN_PAGE {index:#{block_index}}]->(p#{page_num})")
      # neo4j_blocks.concat neo4j_lines

      block_data = {
          id: block_id,
          target: block_annot['on'][0..block_annot['on'].index('#')-1],
          selector: block_annot['on'][block_annot['on'].index('#')..-1],
          level: "block",
          level_reading_order: block_index,
          body: "<p>#{block_text.join(' ')}</p>"
      }
      SolrService.add block_data
    end
    # neo4j_page.concat neo4j_blocks
    # puts neo4j_page.join("\n")
    return page_ocr_text, block_annotation_list.to_json, line_annotation_list.to_json, word_annotation_list.to_json
  end
}