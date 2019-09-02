pagexml_path = "/home/axel/data_bruxelles/aze_1918"
aze_2018_issues_ids = NewseyeSolrService.query({q: "year_isi:1918 AND has_model_ssim:Issue AND member_of_collection_ids_ssim:arbeiter_zeitung", rows: 1000, fl: 'id'}).map{ |i| i['id']}
ind = 0
aze_2018_issues_ids.each do |issue_id|
  ind += 1
  begin
    puts "Processing issue #{ind} out of #{aze_2018_issues_ids.size}"
    i = Issue2.from_solr(issue_id, false, false)
    articles_to_save = []
    (1...i.nb_pages).each do |pagenum|
      myparser = MyParser.new i.id, i.date_created, i.language, i.newspaper_id, pagenum
      parser = Nokogiri::XML::SAX::Parser.new(myparser)
      path = "#{pagexml_path}/ANNO__Arbeiter_Zeitung__#{i.date_created.to_date.to_s}__Seite_#{pagenum}.xml"
      File.open(path) do |f|
        parser.parse f
      end
      puts myparser.page_all_text
      articles_to_save.concat myparser.articles.values
    end
    puts "Adding #{articles_to_save.size} articles..."
    puts NewseyeSolrService.add articles_to_save.map(&:to_solr)
    puts NewseyeSolrService.commit
  rescue => e
    puts "Error during processing: #{$!}"
    puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
    next
  end
end

BEGIN {
  class MyParser < Nokogiri::XML::SAX::Document

    attr_accessor :articles, :page_all_text

    def initialize(issue_id, date_created, lang, npid, page)
      @issue_id = issue_id
      @date_created = date_created
      @language = lang
      @newspaper_id = npid
      @pagenum = page
    end

    def start_document
      @articles = Hash.new
      @page_all_text = []

      @current_reading_order = -1
      @current_line_text = ''
      @current_article_id = nil
      @in_text_region = false
      @in_unicode = false
      @in_line = false
    end

    def end_document
      @articles.values.map { |a| a.all_text = a.all_text.join("\n") }
      @page_all_text = @page_all_text.join("\n")
    end

    def start_element(name, attrs = [])
      at = Hash[attrs]

      if name == 'TextRegion'
        @in_text_region = true
      end

      if name == 'Unicode'
        @in_unicode = true
      end

      if name == 'TextLine'
        @in_line = true
        if (match = at['custom'].match(/readingOrder {index:([0-9]+);} structure {id:a([0-9]+); type:article;}/i))
          @current_reading_order, @current_article_id = match.captures
        end
        if @articles[@current_article_id] == nil and @current_article_id != nil
          @articles[@current_article_id] = Article2.new
          @articles[@current_article_id].id = "#{@issue_id}_article_#{@current_article_id}"
          @articles[@current_article_id].date_created = @date_created
          @articles[@current_article_id].language = @language
          @articles[@current_article_id].newspaper = @newspaper_id
          @articles[@current_article_id].issue_id = @issue_id
          @articles[@current_article_id].all_text = []
          @articles[@current_article_id].canvases_parts = []
        end
        # @current_article.title = article_title
      end
      if name == 'Coords' and @current_article_id != nil
        points = at['points'].split(' ').map { |c| c.split(',').map(&:to_i) }
        max_x = points.map(&:first).max
        max_y = points.map(&:last).max
        min_x = points.map(&:first).min
        min_y = points.map(&:last).min
        @articles[@current_article_id].canvases_parts << "#{Rails.configuration.newseye_services['host']}/iiif/#{@issue_id}/canvas/page_#{@pagenum}#xywh=#{min_x},#{min_y},#{max_x-min_x},#{max_y-min_y}"
      end
    end

    def characters(string)
      if @in_unicode and @current_article_id != nil
        @articles[@current_article_id].all_text << string
      end
      if @in_text_region and !@in_line and @in_unicode
        @page_all_text << string.strip
      end
    end

    def end_element(name)
      if name == 'TextLine'
        @current_article_id = nil
        @in_line = false
      end
      if name == 'TextRegion'
        @in_text_region = false
      end
      if name == 'Unicode'
        @in_unicode = false
      end
    end
  end
}