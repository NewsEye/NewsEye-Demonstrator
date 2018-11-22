
puts "seeding..."

json_data = JSON.parse(File.read(File.join(File.dirname(__FILE__), './seeds_data/data.json')))

json_data.each do |newspaper|
  newspaper = newspaper.with_indifferent_access
  puts "adding newspaper %s" % newspaper[:title]
  np = Newspaper.new
  np.id = newspaper[:title].to_ascii.sub(' ', '_')
  np.title = newspaper[:title]
  np.publisher = newspaper[:publisher]
  np.language = newspaper[:language]
  np.datefrom = newspaper[:datefrom]
  np.dateto = newspaper[:dateto]
  np.location = newspaper[:location]
  np.save
  newspaper[:issues].each do |np_issue|
    puts "adding issue %s" % np_issue[:id]
    issue = Issue.new
    issue.original_uri = np_issue[:original_uri]
    issue.id = np.id + '_' + np_issue[:id]
    issue.publisher = np_issue[:publisher]
    issue.title = np_issue[:title]
    issue.date_created = np_issue[:date_created]
    issue.language = np_issue[:language]
    issue.nb_pages = np_issue[:nb_pages]
    issue.save
    issue_ocr_text = ''
    np_issue[:pages].each do |issue_page|
      puts "adding page %i out of %i" % [issue_page[:page_number], np_issue[:pages].length]

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
          issue.thumbnail_url = "http://localhost:3000/iiif/#{issue.id}_page_1/full/,200/0/default.jpg"
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

      ###### Finalize ######

      pfs.save
      issue.ordered_members << pfs
      pfs.save
      issue.save
      issue_ocr_text += ocr_full_text
    end
    SolrService.commit
    issue.all_text = issue_ocr_text
    np.members << issue
    issue.member_of_collections << np
    issue.save
    np.save
  end
end

BEGIN {
  def parse_alto_index(doc, doc_id, page_num, scale_factor)
    page_ocr_text = ''
    block_annotation_list = {}
    block_annotation_list['@context'] = 'http://iiif.io/api/presentation/2/context.json'
    block_annotation_list['@id'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/list/page_#{page_num}_ocr_block_level"
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
    line_annotation_list['@id'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/list/page_#{page_num}_ocr_line_level"
    line_annotation_list['@type'] = 'sc:AnnotationList'
    line_annotation_list['resources'] = []
    line_annotation_list['within'] = {}
    line_annotation_list['within']['@id'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/layer/ocr_line_level"
    line_annotation_list['within']['@type'] = 'sc:Layer'
    line_annotation_list['within']['label'] = 'OCR Layer'

    nb_blocks = doc.xpath('//TextBlock').size
    total_word_index = 0
    total_line_index = 0
    doc.xpath('//TextBlock').each_with_index do |block, block_index|
      print "block #{block_index+1} out of #{nb_blocks}\r"
      block_id = "#{doc_id}_#{page_num}_block_#{block_index}"
      block_text = []
      block_confidence = 0
      nb_lines = block.children.select{|line| line.name == 'TextLine'}.size
      block.children.select{|line| line.name == 'TextLine'}.each_with_index do |line, line_index|
        line_index = total_line_index + line_index
        line_id = "#{doc_id}_#{page_num}_line_#{line_index}"
        line_text = []
        line_confidence = 0
        nb_words = line.children.select{|str| str.name == 'String'}.size
        line.children.select{|str| str.name == 'String'}.each_with_index do |word, word_index|
          word_index = total_word_index + word_index
          word_id = "#{doc_id}_#{page_num}_word_#{word_index}"
          str_content = word['CONTENT']#.force_encoding(encoding).encode('UTF-8')
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
          word_annot['on'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/canvas/page_#{page_num}#xywh=#{word['HPOS'].to_i*scale_factor},#{word['VPOS'].to_i*scale_factor},#{word['WIDTH'].to_i*scale_factor},#{word['HEIGHT'].to_i*scale_factor}"
          word_annotation_list['resources'] << word_annot
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
        total_word_index += nb_words
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
        line_annot['on'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/canvas/page_#{page_num}#xywh=#{line['HPOS'].to_i*scale_factor},#{line['VPOS'].to_i*scale_factor},#{line['WIDTH'].to_i*scale_factor},#{line['HEIGHT'].to_i*scale_factor}"
        line_annotation_list['resources'] << line_annot
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
      total_line_index += nb_lines
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
      block_annot['on'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/canvas/page_#{page_num}#xywh=#{block['HPOS'].to_i*scale_factor},#{block['VPOS'].to_i*scale_factor},#{block['WIDTH'].to_i*scale_factor},#{block['HEIGHT'].to_i*scale_factor}"
      block_annotation_list['resources'] << block_annot

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
    return page_ocr_text, block_annotation_list.to_json, line_annotation_list.to_json, word_annotation_list.to_json
  end
}