require 'open-uri'
puts "seeding..."

alto = 'alto'
main_directory = '/home/axel/newseye_data/bnf/la_presse'
metadata_dir = "/home/axel/newseye_data/bnf/la_presse/metadata"
mapping = JSON.parse(File.open("/home/axel/id_mapping_presse.json").read)

##### Create or get newspaper
npid = 'la_presse'
if Newspaper.exists?(npid)
  puts "newspaper %s already exists" % 'La Presse'
  np = Newspaper.find(npid)
else
  puts "adding newspaper %s" % 'La Presse'
  np = Newspaper.new
  np.id = npid
  np.title = 'La Presse'
  # np.publisher = newspaper[:publisher]
  np.language = 'fr'
  np.save
end
############################

ids_query = 'http://localhost:8983/solr/hydra-development/select?fl=id&q=has_model_ssim:Issue&wt=json&rows=1000000'
processed_ids = JSON.parse(open(ids_query).read)['response']['docs'].map{|h| h['id']}

nb_issues_dir = Dir[main_directory + "/*"].size
issue_ind = 0
for issue_dir in Dir[main_directory + "/*"]
  issue_ind += 1
  bad_id = issue_dir.split('/')[-1].split('_')[2..-1].join('_')
  ark = mapping[bad_id]
  issueid = np.id + '_' + ark.split('/')[1..-1].join('-')
  if processed_ids.include? issueid
    puts " issue %s already exists" % issueid
    next
  end
  should_process = false
  if Issue.exists?(issueid)
    issue = Issue.find(issueid)
    if issue.all_text.nil?
      should_process = true
    else
      puts " issue %s already exists" % issueid
    end
  else
    issue = Issue.new
    issue.id = issueid
    should_process = true
  end
  if should_process
    json_metadata = JSON.parse(File.open("#{metadata_dir}/#{ark.split('/')[1..-1].join('-')}.json").read).with_indifferent_access
    puts " adding issue #{issueid} (#{issue_ind} out of #{nb_issues_dir})"
    issue.original_uri = json_metadata[:original_uri]
    issue.publisher = json_metadata[:publisher]
    issue.contributor = json_metadata[:contributor]
    issue.title = json_metadata[:title]
    issue.date_created = json_metadata[:date_created]
    issue.nb_pages = json_metadata[:pages].size
    issue.language = json_metadata[:language]
    # SHould I remove this save to prevent duplicates in solr index ?
    # issue.save
    issue_ocr_text = ''
    alto_pages = {}
    json_metadata[:pages].each do |issue_page|
      puts "  adding page %i out of %i" % [issue_page[:page_number], json_metadata[:pages].length]

      pfs = PageFileSet.new
      pfs.id = issueid + "_page_#{issue_page[:page_number]}"
      pfs.page_number = issue_page[:page_number]

      pfs.iiif_url = (issue.original_uri + "/f#{pfs.page_number}").insert(issue.original_uri.index('ark:/'), 'iiif/')
      info_json = JSON.load(open(pfs.iiif_url+'/info.json'))
      pfs.height = info_json['height'].to_i
      pfs.width = info_json['width'].to_i
      pfs.mime_type = 'image/jpeg'
      if issue_page[:page_number] == 1
        issue.thumbnail_url = "#{pfs.iiif_url}/full/,200/0/default.jpg"
      end

      ###### Parse OCR and add full text property ######

      # encoding = CharlockHolmes::EncodingDetector.detect(File.read(Rails.root.to_s + issue_page[:ocr_path]))[:ruby_encoding]
      ocr_file = open(issue_dir + '/'+ alto + '/' + pfs.page_number.to_s.rjust(8, '0') + '.xml', 'r')
      Hydra::Works::AddFileToFileSet.call(pfs, ocr_file, :alto_xml)
      ocr_file.rewind
      ocr = Nokogiri::XML(ocr_file) #, nil, encoding)
      ocr.remove_namespaces!
      alto_pages[issue_page[:page_number]] = ocr

      ###### IIIF Annotation generation ######

      scale_factor = pfs.height.to_f / ocr.xpath('//Page')[0]['HEIGHT'].to_f
      solr_hierarchy, ocr_full_text, block_annots, line_annots, word_annots = parse_alto_index(ocr, issue.id, pfs.page_number, scale_factor)

      annotation_file = Tempfile.new(%w(annotation_list_word_level .json), Rails.root.to_s + '/tmp', encoding: 'UTF-8')
      annotation_file.write(word_annots)
      annotation_file.close
      annotation_file = open(annotation_file.path, 'r')
      Hydra::Works::AddFileToFileSet.call(pfs, annotation_file, :ocr_word_level_annotation_list)
      annotation_file.close

      annotation_file = Tempfile.new(%w(annotation_list_line_level .json), Rails.root.to_s + '/tmp', encoding: 'UTF-8')
      annotation_file.write(line_annots)
      annotation_file.close
      annotation_file = open(annotation_file.path, 'r')
      Hydra::Works::AddFileToFileSet.call(pfs, annotation_file, :ocr_line_level_annotation_list)
      annotation_file.close

      annotation_file = Tempfile.new(%w(annotation_list_block_level .json), Rails.root.to_s + '/tmp', encoding: 'UTF-8')
      annotation_file.write(block_annots)
      annotation_file.close
      annotation_file = open(annotation_file.path, 'r')
      Hydra::Works::AddFileToFileSet.call(pfs, annotation_file, :ocr_block_level_annotation_list)
      annotation_file.close

      ###### Finalize ######
      pfs.to_solr_annots = false
      pfs.annot_hierarchy = solr_hierarchy
      # puts "######### seeds.rb"
      # puts pfs.annot_hierarchy.first
      # puts "######### seeds.rb"
      # pfs.save
      ActiveFedora::SolrService.instance.conn.delete_by_query("id:#{pfs.id} -level:[* TO *]") # delete duplicates without level field
      issue.ordered_members << pfs # this saves pfs
      issue_ocr_text += ocr_full_text
    end

    issue.save

    ###### METS parsing and article annotations ######

    puts "  adding articles from METS..."
    mets_file = Dir["#{issue_dir}/*.xml"][0]
    encoding = CharlockHolmes::EncodingDetector.detect(File.read(mets_file))[:ruby_encoding]
    mets_doc = File.open(mets_file) do |f|
      Nokogiri::XML(f, nil, encoding)
    end
    mets_doc.remove_namespaces!

    # puts "title section : "
    s = mets_doc.xpath("/descendant::structMap[@TYPE='LOGICAL']/descendant::div[@TYPE='ISSUE']/div[@TYPE='TITLE_SECTION']//@BEGIN")
    s = s.map(&:text)

    canvases_parts = []
    title_bboxes = get_bbox(alto_pages, s)
    title_bboxes.keys.each do |page|
      title_bboxes[page].each do |bbox|
        hpos, vpos, width, height = bbox
        # puts "hpos: #{hpos}, vpos: #{vpos}, width: #{width}, height: #{height}"
        canvases_parts << "#{Rails.configuration.newseye_services['host']}/iiif/#{issue.id}/canvas/page_#{page}#xywh=#{hpos},#{vpos},#{width},#{height}"
      end
    end
    unless canvases_parts.empty?
      article = Article.new
      article.id = "#{issue.id}_article_0"
      article.title = 'Heading'
      article.date_created = issue.date_created
      article.language = issue.language
      article.all_text = get_text(alto_pages, s)
      article.member_of_collections << np
      article.canvases_parts = canvases_parts
      article.read_groups = ["admin", "researcher"]
      issue.members << article
    end

    # solr_heading_article = {
    #     "id": "#{issue.id}_article_0",
    #     "level": "0.articles",
    #     "title_t#{issue.language}_siv": 'Heading',
    #     "content_t#{issue.language}_siv": get_text(alto_pages, s),
    #     "from_issue_ssi": issue.id,
    #     "has_model_ssim": 'Article',
    #     "member_of_collection_ids_ssim": np.id,
    #     "canvases_parts_ssm": canvases_parts
    # }
    # issue.articles << solr_heading_article
    # puts
    # puts "articles"
    mets_doc.xpath("/descendant::structMap[@TYPE='LOGICAL']/descendant::div[@TYPE='ISSUE']/div[@TYPE='CONTENT']//div[@TYPE='ARTICLE']").each_with_index do |article, idx|
      canvases_parts = []
      # puts article.xpath("./@ID")
      tbs = {heading: [], body: []}
      tbs[:heading].concat(article.xpath(".//div[@TYPE='HEADING']//@BEGIN").map(&:text))
      tbs[:body].concat(article.xpath(".//div[@TYPE='BODY']//@BEGIN").map(&:text))
      # puts "heading : #{tbs[:heading].size} textblocks"
      heading_bboxes = get_bbox(alto_pages, tbs[:heading])
      heading_bboxes.keys.each do |page|
        heading_bboxes[page].each do |bbox|
          hpos, vpos, width, height = bbox
          # puts "  hpos: #{hpos}, vpos: #{vpos}, width: #{width}, height: #{height}"
          canvases_parts << "#{Rails.configuration.newseye_services['host']}/iiif/#{issue.id}/canvas/page_#{page}#xywh=#{hpos},#{vpos},#{width},#{height}"
        end
      end
      article_title = get_text(alto_pages, tbs[:heading])
      article_title = article_title == "" ? "placeholder title" : article_title
      # puts "body : #{tbs[:body].size} textblocks"
      body_bboxes = get_bbox(alto_pages, tbs[:body])
      body_bboxes.keys.each do |page|
        # puts "  bboxes in page #{page}: "
        body_bboxes[page].each do |bbox|
          hpos, vpos, width, height = bbox
          # puts "    hpos: #{hpos}, vpos: #{vpos}, width: #{width}, height: #{height}"
          canvases_parts << "#{Rails.configuration.newseye_services['host']}/iiif/#{issue.id}/canvas/page_#{page}#xywh=#{hpos},#{vpos},#{width},#{height}"
        end
      end
      article_body = get_text(alto_pages, tbs[:body])

      article = Article.new
      article.id = "#{issue.id}_article_#{idx+1}"
      article.title = article_title
      article.date_created = issue.date_created
      article.language = issue.language
      article.all_text = article_body
      article.member_of_collections << np
      article.canvases_parts = canvases_parts
      article.read_groups = ["admin", "researcher"]
      article.discover_groups = ["admin", "researcher"]
      article.edit_groups = ["admin", "researcher"]
      issue.members << article

      # solr_article = {
      #     "id": "#{issue.id}_article_#{idx+1}",
      #     "level": "0.articles",
      #     "title_t#{issue.language}_siv": article_title,
      #     "content_t#{issue.language}_siv": article_body,
      #     "from_issue_ssi": issue.id,
      #     "has_model_ssim": 'Article',
      #     "member_of_collection_ids_ssim": np.id,
      #     "canvases_parts_ssm": canvases_parts
      # }
      # issue.articles << solr_article
    end

    ###### finalize ######

    issue.all_text = issue_ocr_text
    issue.member_of_collections << np
    issue.read_groups = ["admin", "researcher"]
    issue.discover_groups = ["admin", "researcher"]
    issue.edit_groups = ["admin", "researcher"]
    # issue.to_solr_articles = true
    np.members << issue # save issue-rw-r--r--  1 axel axel     807 Feb 24 11:45 .profile

    np.save # delete duplicates without all_text
  end  # Issue is processed
  # The following is not working...
  ActiveFedora::SolrService.instance.conn.delete_by_query("has_model_ssim:Issue -member_of_collection_ids_ssim:*")
end

BEGIN {
  def parse_alto_index(doc, doc_id, page_num, scale_factor, generate_neo4j=false)
    solr_hierarchy = []
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
    in_page_word_index = 0
    in_page_line_index = 0
    # neo4j_blocks = []
    doc.xpath('//TextBlock').each_with_index do |block, block_index|
      print "  block #{block_index+1} out of #{nb_blocks}\r"
      solr_block = {}
      solr_block['_childDocuments_'] = []
      block_id = "#{doc_id}_#{page_num}_block_#{block_index}"
      block_text = []
      block_confidence = 0
      nb_lines = block.children.select{|line| line.name == 'TextLine'}.size
      # neo4j_lines = []
      in_block_word_index = 0
      block.children.select{|line| line.name == 'TextLine'}.each_with_index do |line, in_block_line_index|
        solr_line = {}
        solr_line['_childDocuments_'] = []
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

          solr_word = {
              id: word_id,
              selector: word_annot['on'][word_annot['on'].index('#')..-1],
              level: "4.pages.blocks.lines.words",
              level_reading_order: word_index,
              text: str_content,
              confidence: word_annot['metadata']['word_confidence']
          }
          solr_word.stringify_keys!

          solr_line['_childDocuments_'] << solr_word

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

        solr_line['id'] = line_id
        solr_line['selector'] = line_annot['on'][line_annot['on'].index('#')..-1]
        solr_line['level'] = "3.pages.blocks.lines"
        solr_line['level_reading_order'] = line_index
        solr_line['text'] = line_text.join(' ')
        solr_line['confidence'] = line_annot['metadata']['word_confidence']
        solr_block['_childDocuments_'] << solr_line
        # SolrService.add line_data
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

      solr_block['id'] = block_id
      solr_block['selector'] = block_annot['on'][block_annot['on'].index('#')..-1]
      solr_block['level'] = "2.pages.blocks"
      solr_block['level_reading_order'] = block_index
      solr_block['text'] = block_text.join(' ')
      solr_block['confidence'] = block_annot['metadata']['word_confidence']
      # SolrService.add block_data
      solr_hierarchy << solr_block
    end
    # neo4j_page.concat neo4j_blocks
    # puts neo4j_page.join("\n")
    return solr_hierarchy, page_ocr_text, block_annotation_list.to_json, line_annotation_list.to_json, word_annotation_list.to_json
  end

  def get_text_from_block_id(alto_docs, textblock_id)
    page = textblock_id[1...textblock_id.index('_')].to_i
    alto_docs[page].xpath("//TextBlock[@ID='#{textblock_id}']//@CONTENT").map(&:to_s).join(' ')
  end

  def get_text(alto_docs, textblocks)
    texts = textblocks.map{ |tb| get_text_from_block_id(alto_docs, tb) }
    texts.join(' ')
  end

  def get_bbox(alto_docs, textblocks)
    bboxes = {}
    pages = textblocks.map{ |tb| tb[1...tb.index('_')].to_i }.uniq
    pages.each do |page|
      # min_hpos = 100000
      # min_vpos = 100000
      # max_hpos = 0
      # max_vpos = 0
      bboxes[page] = []
      textblocks.select{ |tb| tb.index("P#{page}_") }.each do |tb|
        hpos = alto_docs[page].xpath("//TextBlock[@ID='#{tb}']/@HPOS").to_s.to_i
        vpos = alto_docs[page].xpath("//TextBlock[@ID='#{tb}']/@VPOS").to_s.to_i
        width = alto_docs[page].xpath("//TextBlock[@ID='#{tb}']/@WIDTH").to_s.to_i
        height = alto_docs[page].xpath("//TextBlock[@ID='#{tb}']/@HEIGHT").to_s.to_i
        # hpos2 = hpos + width
        # vpos2 = vpos + height
        # min_hpos = hpos < min_hpos ? hpos : min_hpos
        # min_vpos = vpos < min_vpos ? vpos : min_vpos
        # max_hpos = hpos2 > max_hpos ? hpos2 : max_hpos
        # max_vpos = vpos2 > max_vpos ? vpos2 : max_vpos
        # bboxes[page] << [min_hpos, min_vpos, max_hpos-min_hpos, max_vpos-min_vpos]
        bboxes[page] << [hpos, vpos, width, height]
      end
    end
    bboxes
  end
}
