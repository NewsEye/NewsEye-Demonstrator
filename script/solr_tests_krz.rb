require 'open-uri'
puts "seeding..."

main_directory = '/home/axel/data_bruxelles/aze_2018/new'


##### Create or get newspaper
npid = 'arbeiter_zeitung'
# nptitle = 'Arbeiter Zeitung'
# if Newspaper.exists?(npid)
#   puts "newspaper %s already exists" % nptitle
#   np = Newspaper.find(npid)
# else
#   puts "adding newspaper %s" % nptitle
#   np = Newspaper.new
#   np.id = npid
#   np.title = nptitle
#   # np.publisher = newspaper[:publisher]
#   np.language = 'de'
#   np.save
# end
############################

ids_query = 'http://localhost:8983/solr/hydra-development/select?fl=id&q=has_model_ssim:Issue&wt=json&rows=1000000'
processed_ids = JSON.parse(open(ids_query).read)['response']['docs'].map{|h| h['id']}
nbissues = Dir[main_directory + "/*.json"].size
i = 0
for json_issue in Dir[main_directory + "/*.json"]
  begin
    i += 1
    time_start = Time.now
    begin
      json_content = File.read(json_issue)
      issue_data = JSON.parse(json_content).with_indifferent_access
      issue_data[:date_created] = issue_data[:date_created][-1] == '-' ? issue_data[:date_created][0..-2] : issue_data[:date_created]
    rescue JSON::ParserError
      next
    end

    issueid = npid + '_' + issue_data[:id]
    if processed_ids.include? issueid
      puts " issue %s already exists" % issueid
      next
    end
    # should_process = false
    # if Issue.exists?(issueid)
    #   issue = Issue.find(issueid)
    #   if issue.all_text.nil?
    #     should_process = true
    #     issue_data[:pages].each do |issue_page|
    #       fpath = main_directory + '/' + issue_page[:ocr_path][15..-1]
    #       should_process = File.file?(fpath)
    #     end
    #     puts " issue %s is missing files" % issue_data[:id] unless should_process
    #   else
    #     puts " issue %s already exists" % issue_data[:id]
    #   end
    # else
    #   should_process = true
    #   issue_data[:pages].each do |issue_page|
    #     fpath = main_directory + '/' + issue_page[:ocr_path][15..-1]
    #     should_process = File.file?(fpath)
    #   end
    #   puts " issue %s is missing files" % issue_data[:id] unless should_process
    #   issue = Issue2.new
    #   issue.id = issueid
    # end
    issue = Issue2.new
    issue.id = issueid
    should_process = true

    if should_process
      puts " adding issue #{issue_data[:id]} (#{i} out of #{nbissues})"
      issue.original_uri = issue_data[:original_uri]
      issue.title = issue_data[:title]
      issue.date_created = issue_data[:date_created]
      issue.nb_pages = issue_data[:pages].size
      issue.language = 'de' # issue_data[:language]
      issue.pages = []
      issue_ocr_text = []
      alto_pages = {}
      all_blocks_texts = {}
      issue_data[:pages].each do |issue_page|
        puts "  adding page %i out of %i" % [issue_page[:page_number], issue_data[:pages].length]

        pfs = PageFileSet2.new
        pfs.id = issue.id + '_' + issue_page[:id].split('_')[1..-1].join('_')
        pfs.page_number = issue_page[:page_number]
        pfs.language = 'de'

        # pfs.iiif_url = "https://iiif-auth.onb.ac.at/images/ANNO/#{issue_data[:id]}/#{pfs.page_number.to_s.rjust(8,'0')}"
        info_json_url = "https://iiif-auth.onb.ac.at/images/ANNO/#{issue_data[:id]}/#{pfs.page_number.to_s.rjust(8,'0')}/info.json"
        pfs.iiif_url = "#{Rails.configuration.newseye_services['host']}/iiif/#{issue.id}_page_#{pfs.page_number}"
        info_json = JSON.load(open(info_json_url))
        pfs.height = info_json['height'].to_i
        pfs.width = info_json['width'].to_i
        pfs.mime_type = 'image/jpeg'
        if issue_page[:page_number] == 1
          issue.thumbnail_url = "#{pfs.iiif_url}/full/,200/0/default.jpg"
        end

        ###### Parse OCR and add full text property ######

        pfs.ocr_path = main_directory + '/' + issue_page[:ocr_path][15..-1]
        ocr_file = open(pfs.ocr_path, 'r')
        ocr = Nokogiri::XML(ocr_file) #, nil, encoding)
        ocr.remove_namespaces!
        alto_pages[issue_page[:page_number]] = ocr

        ###### IIIF Annotation generation ######

        scale_factor = pfs.height.to_f / ocr.xpath('//Page')[0]['HEIGHT'].to_f
        # solr_hierarchy, ocr_full_text, block_annots, line_annots, word_annots = parse_alto_index(ocr, issue.id, pfs.page_number, scale_factor)
        solr_hierarchy, ocr_full_text, blocks_texts = parse_alto_index2(main_directory + '/' + issue_page[:ocr_path][15..-1], issue.id, pfs.page_number, scale_factor)
        all_blocks_texts = all_blocks_texts.merge(blocks_texts)

        ###### Finalize ######
        pfs.to_solr_annots = true
        pfs.annot_hierarchy = solr_hierarchy
        issue.pages << pfs
        issue_ocr_text << ocr_full_text
      end

      ###### finalize ######

      issue.all_text = issue_ocr_text.join("\n")
      issue.newspaper_id = npid

      begin
        puts NewseyeSolrService.add issue.pages.map(&:to_solr)+[issue.to_solr]
        puts NewseyeSolrService.commit
      rescue => e
        puts "Error during processing: #{$!}"
        puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
        next
      end
      time_end = Time.now
      puts "Issue was processed in #{(time_end-time_start).seconds} seconds."
    end
  rescue => e
    puts "Error during processing: #{$!}"
    puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
    next
  end
end  # Issue is processed

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