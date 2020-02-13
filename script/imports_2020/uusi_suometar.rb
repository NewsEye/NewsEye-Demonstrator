npid = "uusi_suometar"
np_orig_id = '1457-4721'
save_dir = "/home/axel/solr_backup/#{npid}"
#all_metadata_path = "/home/axel/production_storage/fi/uusi_suometar/import_1457-4721"
#pxml_path = "/home/axel/transkribus_data/trnskrbs_52768/col"
all_metadata_path = "/home/axel/uusi_suometar_tests/old"
pxml_path = "/home/axel/uusi_suometar_tests/new"

mapping = {}
File.open("/home/axel/uusi_suometar_tests/final_uusi_mapping") do |f|
  mapping = JSON.parse(f.read)
end

#ids_query = "http://localhost:8990/solr/newseye_collection/select?fl=id&q=has_model_ssim:Issue%20AND%20member_of_collection_ids_ssim:#{npid}&wt=json&rows=1000000"
ids_query = "http://localhost:8983/solr/hydra-development/select?fl=id&q=has_model_ssim:Issue%20AND%20member_of_collection_ids_ssim:#{npid}&wt=json&rows=1000000"
processed_ids = JSON.parse(open(ids_query).read)['response']['docs'].map{|h| h['id']}
nbissues = Dir[all_metadata_path + "/*.json"].size

Dir.chdir(pxml_path)
Dir.glob('*').select do |f|
  File.directory? f
end.each_with_index do |dir_path, idx|
  dir_path = "#{pxml_path}/#{dir_path}"
  issue_id = mapping[dir_path.split('/')[-1]]
  if processed_ids.include? issue_id
    puts " issue %s already exists" % issue_id
    next
  end
  puts "Processing #{issue_id} ((#{idx+1} out of #{nbissues}))..."
  begin
    json_content = File.read("#{all_metadata_path}/#{np_orig_id}#{issue_id.split('_')[-1]}.json")
    issue_data = JSON.parse(json_content).with_indifferent_access
  rescue JSON::ParserError
    puts "Error reading JSON metadata file. Skipping..."
    next
  end
  articles_to_save = []
  issue_all_text = []
  issue = Issue2.new
  issue.id = issue_id
  issue.newspaper_id = npid
  issue.original_uri = issue_data[:original_uri]
  issue.title = issue_data[:title]
  issue.date_created = issue_data[:date_created]
  issue.nb_pages = issue_data[:pages].size
  issue.language = 'fi' # issue_data[:language]
  issue.pages = []
  id_start_from = 0
  issue_manifest = {"sequences" => [{"canvases" => []}]}
  Dir["#{dir_path}/*.pxml"].sort.each_with_index do |pxml_path, idx|
    pfs = PageFileSet2.new
    pfs.page_number = idx + 1
    pfs.id = "#{issue.id}_page_#{idx+1}"
    pfs.language = 'fi'
    pfs.image_path = "#{all_metadata_path}/#{np_orig_id}#{issue_id.split('_')[-1]}_page_#{pfs.page_number}.jpg"
    width, height = FastImage.size(pfs.image_path)
    pfs.iiif_url = "#{Rails.configuration.newseye_services['host']}/iiif/#{issue.id}_page_#{pfs.page_number}"
    issue_manifest["sequences"][0]["canvases"] << {"images" => [{"resource" => {"service" => {"@id" => pfs.iiif_url}}}]}
    pfs.height = height
    pfs.width = width
    pfs.mime_type = 'image/jpeg'
    if idx == 0
      issue.thumbnail_url = "#{Rails.configuration.newseye_services['host']}/iiif/#{issue.id}_page_1/full/,200/0/default.jpg"
    end

    myparser = MyParser.new issue.id, issue.date_created, issue.language, issue.newspaper_id, idx+1, id_start_from, pfs.height
    parser = Nokogiri::XML::SAX::Parser.new(myparser)
    File.open(pxml_path) do |f|
      parser.parse f
    end
    articles_to_save.concat myparser.articles.values
    id_start_from = myparser.last_id
    issue_all_text << myparser.page_all_text
    issue.pages << pfs
  end
  issue_all_text = issue_all_text.join("\n")
  issue_all_text.gsub! "¬\n", ""
  issue.all_text = issue_all_text

  issue_manifest = issue_manifest.stringify_keys!
  articles_to_save.map! { |art| art.to_solr(issue_manifest) }
  json_data = issue.pages.map(&:to_solr) + [issue.to_solr] + articles_to_save
  File.open("#{save_dir}/#{issue.id}.json", 'w') do |f| f.write json_data.to_json end
  puts NewseyeSolrService.add json_data
  puts NewseyeSolrService.commit
end


BEGIN {

  require 'open-uri'
  require 'json'
  require 'nokogiri'

  class MyParser < Nokogiri::XML::SAX::Document

    attr_accessor :articles, :page_all_text, :last_id, :id_start_from, :original_height, :scale_factor

    def initialize(issue_id, date_created, lang, npid, page, id_start_from, original_height)
      @issue_id = issue_id
      @date_created = date_created
      @language = lang
      @newspaper_id = npid
      @pagenum = page
      @id_start_from = id_start_from
      @last_id = id_start_from
      @original_height = original_height
    end

    def start_document
      @articles = Hash.new
      @page_all_text = []
      @current_reading_order = -1
      @current_line_text = ""
      @current_article_id = nil
      @in_text_region = false
      @in_unicode = false
      @in_line = false
    end

    def end_document
      @articles.values.map { |a| a.all_text = a.all_text.join("\n").gsub "¬\n", "" }
      @page_all_text = @page_all_text.join("\n")
    end

    def start_element(name, attrs = [])
      at = Hash[attrs]

      if name == 'Page'
        @scale_factor = @original_height.to_f / at['imageHeight'].to_f
      end

      if name == 'TextRegion'
        @in_text_region = true
      end

      if name == 'Unicode'
        @current_line_text = ""
        @in_unicode = true
      end

      if name == 'TextLine'
        @in_line = true
        if (match = at['custom'].match(/readingOrder {index:([0-9]+);} structure {id:a([0-9]+); type:article;}/i))
          @current_reading_order, @current_article_id = match.captures
          @current_article_id = @current_article_id.to_i
          @current_article_id += @id_start_from
          @last_id = @current_article_id if @current_article_id > @last_id
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
        max_x = (points.map(&:first).max * @scale_factor).to_i
        max_y = (points.map(&:last).max * @scale_factor).to_i
        min_x = (points.map(&:first).min * @scale_factor).to_i
        min_y = (points.map(&:last).min * @scale_factor).to_i
        @articles[@current_article_id].canvases_parts << "#{Rails.configuration.newseye_services['host']}/iiif/#{@issue_id}/canvas/page_#{@pagenum}#xywh=#{min_x},#{min_y},#{max_x-min_x},#{max_y-min_y}"
      end
    end

    def characters(string)
      if @in_unicode and @current_article_id != nil
        @current_line_text = "#{@current_line_text}#{string}"
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
        if @in_line
          @page_all_text << @current_line_text if @current_line_text != ""
        end
        @articles[@current_article_id].all_text << @current_line_text if @current_line_text != ""
        @current_line_text = ""
        @in_unicode = false
      end
    end
  end
}
