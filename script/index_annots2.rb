workdir = '/home/axel/data_nlf_ahmed/data_nlf_ahmed'
processed = File.open('/home/axel/already_processed.log', 'r'){|f| f.readlines}.map(&:strip)
outdir = '/home/axel/data_uusisuometar_ahmed2'
nbissues = Dir[workdir + "/*.json"].size
i = 0
do_process = true
for json_issue in Dir[workdir + "/*.json"]
  do_process = true
  i += 1
  json_content = File.read(json_issue)
  next if json_content == ''
  issue_data = JSON.parse(File.read(json_issue)).with_indifferent_access
  issue_data[:id] = issue_data[:id][9..-1]
  issueid = "uusisuometar_#{issue_data[:id]}"
  next if processed.include? issueid
  puts "processing issue #{i} (#{issueid}) out of #{nbissues}"
  fulltext = ''
  (0..issue_data[:pages].size-1).each do |ind|
    puts "  adding page #{ind+1} out of #{issue_data[:pages].size}"
    ocr_path = "#{workdir}/#{json_issue[json_issue.rindex('/')+1..json_issue.rindex('.')-1]}_page_#{ind+1}.xml"
    begin
      xml = File.open(ocr_path, 'r'){ |f| f.read }
    rescue
      do_process = false
      puts "error missing page"
    end
    ocr = Nokogiri::XML(xml) #, nil, encoding)
    ocr.remove_namespaces!


    scale_factor = 1
    solr_hierarchy, ocr_full_text, block_annots, line_annots, word_annots = parse_alto_index(ocr, "", ind+1, scale_factor)

    fulltext << ocr_full_text
    fulltext << "\n"

  end
  next unless do_process
  fulltext.strip!
  File.open("#{outdir}/#{issueid}.txt", 'w'){ |f| f.write(fulltext) }
  File.open('/home/axel/already_processed.log', 'a') { |f| f << "#{issueid}\n" }
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
    doc.xpath('//TextBlock').each_with_index do |block, block_index|
      print "  block #{block_index+1} out of #{nb_blocks}\r"
      solr_block = {}
      solr_block['_childDocuments_'] = []
      block_id = "#{doc_id}_#{page_num}_block_#{block_index}"
      block_text = []
      block_confidence = 0
      nb_lines = block.children.select{|line| line.name == 'TextLine'}.size
      in_block_word_index = 0
      block.children.select{|line| line.name == 'TextLine'}.each_with_index do |line, in_block_line_index|
        solr_line = {}
        solr_line['_childDocuments_'] = []
        line_index = in_page_line_index + in_block_line_index
        line_id = "#{doc_id}_#{page_num}_line_#{line_index}"
        line_text = []
        line_confidence = 0
        nb_words = line.children.select{|str| str.name == 'String'}.size
        line.children.select{|str| str.name == 'String'}.each_with_index do |word, in_line_word_index|
          word_index = in_page_word_index + in_line_word_index
          word_id = "#{doc_id}_#{page_num}_word_#{word_index}"
          str_content = word['CONTENT']
          page_ocr_text << "#{word['CONTENT']} "
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
        end
        in_page_word_index += nb_words
        in_block_word_index += nb_words
        page_ocr_text.strip!
        page_ocr_text << "\n"
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

        solr_line['id'] = line_id
        solr_line['selector'] = line_annot['on'][line_annot['on'].index('#')..-1]
        solr_line['level'] = "3.pages.blocks.lines"
        solr_line['level_reading_order'] = line_index
        solr_line['text'] = line_text.join(' ')
        solr_line['confidence'] = line_annot['metadata']['word_confidence']
        solr_block['_childDocuments_'] << solr_line
        block_text << line_text.join(' ')
        block_confidence += line_annot['metadata']['word_confidence'].to_f
        # SolrService.add line_data
      end
      in_page_line_index += nb_lines
      page_ocr_text.strip!
      page_ocr_text << "\n"
      block_annot = {}
      block_annot['@type'] = 'oa:Annotation'
      block_annot['motivation'] = 'sc:painting'
      block_annot['resource'] = {}
      block_annot['resource']['@type'] = 'cnt:ContentAsText'
      block_annot['resource']['format'] = 'text/plain'
      block_annot['resource']['chars'] = block_text.join("\n")
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

      solr_block['id'] = block_id
      solr_block['selector'] = block_annot['on'][block_annot['on'].index('#')..-1]
      solr_block['level'] = "2.pages.blocks"
      solr_block['level_reading_order'] = block_index
      solr_block['text'] = block_text.join("\n")
      solr_block['confidence'] = block_annot['metadata']['word_confidence']
      # SolrService.add block_data
      solr_hierarchy << solr_block
    end
    page_ocr_text.strip!
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
      bboxes[page] = []
      textblocks.select{ |tb| tb.index("P#{page}_") }.each do |tb|
        hpos = alto_docs[page].xpath("//TextBlock[@ID='#{tb}']/@HPOS").to_s.to_i
        vpos = alto_docs[page].xpath("//TextBlock[@ID='#{tb}']/@VPOS").to_s.to_i
        width = alto_docs[page].xpath("//TextBlock[@ID='#{tb}']/@WIDTH").to_s.to_i
        height = alto_docs[page].xpath("//TextBlock[@ID='#{tb}']/@HEIGHT").to_s.to_i
        bboxes[page] << [hpos, vpos, width, height]
      end
    end
    bboxes
  end
}