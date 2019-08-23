# NewseyeSolrService.add({id: 1, year_isi: 1923})
# NewseyeSolrService.commit(params: { softCommit: true })

require 'open-uri'

alto = 'alto'
main_directory = '/home/axel/data_bruxelles/l_oeuvre'

npid = 'l_oeuvre'

ids_query = 'http://localhost:8983/solr/hydra-development/select?fl=id&q=has_model_ssim:Issue&wt=json&rows=1000000'
processed_ids = JSON.parse(open(ids_query).read)['response']['docs'].map{|h| h['id']}

nb_issues_dir = Dir[main_directory + "/*"].size
issue_ind = 0
for issue_dir in Dir[main_directory + "/*"]
  begin
    issue_ind += 1
    time_start = Time.now
    metadata_file = Dir["#{issue_dir}/manifest.xml"][0]
    metadata_file = File.open(metadata_file) do |f|
      Nokogiri::XML(f)
    end
    metadata_file.remove_namespaces!
    ark = metadata_file.xpath("/descendant::amdSec/descendant::object[@type='premis:representation']/descendant::objectIdentifierType[text()='ark']")[0].next_element.text

    # bad_id = issue_dir.split('/')[-1].split('_')[2..-1].join('_')
    # ark = mapping[bad_id]
    issueid = npid + '_' + ark.split('/')[1..-1].join('-')
    # next
    if processed_ids.include? issueid
      puts " issue %s already exists" % issueid
      next
    end
    issue = Issue2.new
    issue.id = issueid
    should_process = true

    if should_process
      puts " adding issue #{issueid} (#{issue_ind} out of #{nb_issues_dir})"
      issue.original_uri = "https://gallica.bnf.fr/#{ark}"
      issue.title = metadata_file.xpath("/descendant::dmdSec[@ID='DMD.2']/descendant::spar_dc/title").text.to_s
      issue.date_created = metadata_file.xpath("/descendant::dmdSec[@ID='DMD.2']/descendant::spar_dc/date").text.to_s
      issue.nb_pages = Dir[issue_dir + "/ocr/*"].size
      issue.language = 'fr'
      issue.pages = []
      # SHould I remove this save to prevent duplicates in solr index ?
      # issue.save
      issue_ocr_text = []
      alto_pages = {}
      all_blocks_texts = {}
      # pfs_to_save = []
      Dir[issue_dir + "/ocr/*"].sort.each_with_index do |issue_page, idx|
        puts "  adding page %i out of %i" % [idx + 1, issue.nb_pages]

        pfs = PageFileSet2.new
        pfs.id = issueid + "_page_#{idx + 1}"
        pfs.page_number = idx + 1
        pfs.language = 'fr'
        pfs.iiif_url = (issue.original_uri + "/f#{pfs.page_number}").insert(issue.original_uri.index('ark:/'), 'iiif/')
        info_json = JSON.load(open(pfs.iiif_url+'/info.json'))
        pfs.height = info_json['height'].to_i
        pfs.width = info_json['width'].to_i
        pfs.mime_type = 'image/jpeg'
        if pfs.page_number == 1
          issue.thumbnail_url = "#{pfs.iiif_url}/full/,200/0/default.jpg"
        end

        ###### Parse OCR and add full text property ######

        pfs.ocr_path = issue_dir + '/ocr/X' + pfs.page_number.to_s.rjust(7, '0') + '.xml'
        ocr_file = open(pfs.ocr_path, 'r')

        ocr = Nokogiri::XML(ocr_file)
        ocr.remove_namespaces!
        alto_pages[pfs.page_number] = ocr

        ###### IIIF Annotation generation ######

        scale_factor = pfs.height.to_f / ocr.xpath('//Page')[0]['HEIGHT'].to_f
        # solr_hierarchy, ocr_full_text, block_annots, line_annots, word_annots, blocks_texts = parse_alto_index(ocr, issue.id, pfs.page_number, scale_factor)
        solr_hierarchy, ocr_full_text, blocks_texts = parse_alto_index2(pfs.ocr_path, issue.id, pfs.page_number, scale_factor)
        all_blocks_texts = all_blocks_texts.merge(blocks_texts)

        ###### Finalize ######
        pfs.to_solr_annots = true
        pfs.annot_hierarchy = solr_hierarchy

        issue.pages << pfs

        # pfs_to_save << pfs
        issue_ocr_text << ocr_full_text
      end

      # issue.ordered_members = pfs_to_save # this saves pfs
      issue.all_text = issue_ocr_text.join("\n")
      # issue.read_groups = ["admin", "researcher"]
      # issue.discover_groups = ["admin", "researcher"]
      # issue.member_of_collections << np
      issue.newspaper_id = npid
      begin
        # puts issue.to_solr.to_json

        puts NewseyeSolrService.add issue.pages.map(&:to_solr)+[issue.to_solr]
        # NewseyeSolrService.add issue.to_solr
        puts NewseyeSolrService.commit
        # issue.save
      rescue => e
        puts "Error during processing: #{$!}"
        puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
        next
      end
      # np.members << issue # save issue

      time_end = Time.now
      puts "Issue was processed in #{(time_end-time_start).seconds} seconds."

      ###### METS parsing and article annotations ######

      puts "  adding articles from METS..."
      articles_to_save = []
      issue.mets_path = Dir["#{issue_dir}/toc/*.xml"][0]

      mets_doc = File.open(issue.mets_path) do |f|
        Nokogiri::XML(f)
      end
      mets_doc.remove_namespaces!

      # puts "title section : "
      s = mets_doc.xpath("/descendant::structMap[@TYPE='logical']/descendant::div[@TYPE='ISSUE']/div[@TYPE='TITLESECTION']//@BEGIN")
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
        article = Article2.new
        article.id = "#{issue.id}_article_0"
        article.title = 'Heading'
        article.date_created = issue.date_created
        article.language = issue.language
        article.all_text = get_text(all_blocks_texts, s)
        # article.member_of_collections << np # take lots of time
        article.canvases_parts = canvases_parts
        # article.read_groups = ["admin", "researcher"]
        article.newspaper = npid
        article.issue_id = issue.id
        # article.index_record
        # issue.ordered_members << article

        articles_to_save << article
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
      all_articles = mets_doc.xpath("/descendant::structMap[@TYPE='logical']/descendant::div[@TYPE='ISSUE']/div[@TYPE='CONTENT']//div[@TYPE='ARTICLE']")
      all_articles.each_with_index do |article, idx|
        print "  article #{idx+1} out of #{all_articles.size}\r"
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
        article_title = get_text(all_blocks_texts, tbs[:heading])
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
        article_body = get_text(all_blocks_texts, tbs[:body])

        article = Article2.new
        article.id = "#{issue.id}_article_#{idx+1}"
        article.title = article_title
        article.date_created = issue.date_created
        article.language = issue.language
        article.all_text = article_body
        # article.member_of_collections << np
        article.canvases_parts = canvases_parts
        # article.read_groups = ["admin", "researcher"]
        # article.discover_groups = ["admin", "researcher"]
        # article.edit_groups = ["admin", "researcher"]
        article.newspaper = npid
        article.issue_id = issue.id
        # article.index_record
        # issue.ordered_members << article
        articles_to_save << article
      end
      puts NewseyeSolrService.add articles_to_save.map(&:to_solr)
      puts NewseyeSolrService.commit
      end
  rescue => e
    puts "Error during processing: #{$!}"
    puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
    next
  end
end

BEGIN {
  class MyParser < Nokogiri::XML::SAX::Document

    attr_accessor :solr_hierarchy, :all_text, :blocks_texts

    # Replace #{Rails.configuration.newseye_services['host']}
    # by #{Rails.configuration.newseye_services['host']}

    def initialize(doc_id, page_num, scale_factor)
      @doc_id = doc_id
      @page_num = page_num
      @scale_factor = scale_factor
    end

    def start_document
      @all_text = []
      @solr_hierarchy = []
      @in_page_word_index = 0
      @in_page_line_index = 0
      @in_page_block_index = 0
      @blocks_texts = {}
    end

    def end_document
      @all_text = @all_text.join("\n")
    end

    def start_element(name, attrs = [])
      # Handle each element, expecting the name and any attributes
      at = Hash[attrs]
      case name
      when 'TextBlock'
        @block_text = []
        @solr_block = {}
        @solr_block['_childDocuments_'] = []
        @block_id = "#{@doc_id}_#{@page_num}_block_#{@in_page_block_index}"
        @block_text = []
        @block_confidence = 0
        @block_at = at
        @nb_lines = 0
        # @block_id = at['ID']
      when 'TextLine'
        @line_text = []
        @nb_lines += 1
        @solr_line = {}
        @solr_line['_childDocuments_'] = []
        @line_id = "#{@doc_id}_#{@page_num}_line_#{@in_page_line_index}"
        @line_text = []
        @line_confidence = 0
        @nb_words = 0
        @line_at = at
      when 'String'
        @word_text = at['CONTENT']
        @line_text << @word_text
        @nb_words += 1
        @word_id = "#{@doc_id}_#{@page_num}_word_#{@in_page_word_index}"
        str_content = at['CONTENT']
        word_selector = <<~HEREDOC.gsub(/^[\s\t]*|[\s\t]*\n/, '')
            #xywh=
            #{(at['HPOS'].to_i*@scale_factor).to_i},
            #{(at['VPOS'].to_i*@scale_factor).to_i},
            #{(at['WIDTH'].to_i*@scale_factor).to_i},
            #{(at['HEIGHT'].to_i*@scale_factor).to_i}
        HEREDOC
       on_attr = "#{Rails.configuration.newseye_services['host']}/iiif/#{@doc_id}/canvas/page_#{@page_num}#{word_selector}"
        # @word_annotation_list['resources'] << @word_annot

        solr_word = {
            'id': @word_id,
            'selector': on_attr[on_attr.index('#')..-1],
            'level': "4.pages.blocks.lines.words",
            'level_reading_order': @in_page_word_index,
            'pagenum_isi': @page_num,
            'text': str_content,
            'confidence': at['WC'].to_f
        }
        solr_word.stringify_keys!

        @solr_line['_childDocuments_'] << solr_word
        @line_confidence += at['WC'].to_f
        @in_page_word_index += 1
      end
    end

    def characters(string)
      # Any characters between the start and end element expected as a string
    end

    def end_element(name)
      # Given the name of an element once its closing tag is reached
      case name
      when 'TextBlock'
        @all_text << @block_text.join("\n")
        block_selector = <<~HEREDOC.gsub(/^[\s\t]*|[\s\t]*\n/, '')
        #xywh=
        #{(@block_at['HPOS'].to_i*@scale_factor).to_i},
        #{(@block_at['VPOS'].to_i*@scale_factor).to_i},
        #{(@block_at['WIDTH'].to_i*@scale_factor).to_i},
        #{(@block_at['HEIGHT'].to_i*@scale_factor).to_i}
        HEREDOC
        on_attr = "#{Rails.configuration.newseye_services['host']}/iiif/#{@doc_id}/canvas/page_#{@page_num}#{block_selector}"

        @block_confidence = @block_text.size == 0 ? 0 : @block_confidence / @block_text.size

        @solr_block['id'] = @block_id
        @solr_block['selector'] = on_attr[on_attr.index('#')..-1]
        @solr_block['level'] = "2.pages.blocks"
        @solr_block['level_reading_order'] = @in_page_block_index
        @solr_block['pagenum_isi'] = @page_num
        @solr_block['text'] = @block_text.join("\n")
        @solr_block['confidence'] = @block_confidence
        @solr_hierarchy << @solr_block
        @blocks_texts[@block_at['ID']] = @block_text.join("\n")
        @in_page_block_index += 1
      when 'TextLine'
        @block_text << @line_text.join(' ')
        line_selector = <<~HEREDOC.gsub(/^[\s\t]*|[\s\t]*\n/, '')
          #xywh=
          #{(@line_at['HPOS'].to_i*@scale_factor).to_i},
          #{(@line_at['VPOS'].to_i*@scale_factor).to_i},
          #{(@line_at['WIDTH'].to_i*@scale_factor).to_i},
          #{(@line_at['HEIGHT'].to_i*@scale_factor).to_i}
        HEREDOC
        on_attr = "#{Rails.configuration.newseye_services['host']}/iiif/#{@doc_id}/canvas/page_#{@page_num}#{line_selector}"

        @line_confidence = @line_text.size == 0 ? 0 : @line_confidence / @line_text.size

        @solr_line['id'] = @line_id
        @solr_line['selector'] = on_attr[on_attr.index('#')..-1]
        @solr_line['level'] = "3.pages.blocks.lines"
        @solr_line['level_reading_order'] = @in_page_line_index
        @solr_line['pagenum_isi'] = @page_num
        @solr_line['text'] = @line_text.join(' ')
        @solr_line['confidence'] = @line_confidence
        @solr_block['_childDocuments_'] << @solr_line
        @block_confidence += @line_confidence
        @in_page_line_index += 1
      end
    end

  end

  def parse_alto_index2(path, doc_id, page_num, scale_factor)
    myparser = MyParser.new(doc_id, page_num, scale_factor)
    parser = Nokogiri::XML::SAX::Parser.new(myparser)
    parser.parse(File.open(path))
    # return myparser.solr_hierarchy, myparser.all_text, myparser.block_annotation_list, myparser.line_annotation_list, myparser.word_annotation_list, myparser.blocks_texts
    return myparser.solr_hierarchy, myparser.all_text, myparser.blocks_texts
  end

  def get_text(blocks_texts, textblocks)
    texts = textblocks.map{ |tb| blocks_texts[tb] }
    texts.join("\n")
  end

  def get_bbox(alto_docs, textblocks)
    bboxes = {}
    pages = textblocks.map{ |tb| tb.split('_')[1].to_i }.uniq
    pages.each do |page|
      # min_hpos = 100000
      # min_vpos = 100000
      # max_hpos = 0
      # max_vpos = 0
      bboxes[page] = []
      textblocks.select{ |tb| tb.index("PAG_#{page}_") }.each do |tb|
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