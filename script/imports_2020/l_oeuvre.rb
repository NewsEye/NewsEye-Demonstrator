npid = "l_oeuvre"
save_dir = "/home/axel/solr_backup/#{npid}"
all_metadata_path = "/home/axel/l_oeuvre_tests/old"
pxml_path = "/home/axel/l_oeuvre_tests/new"

# mapping = map_dir_ark(all_metadata_path)
# File.open("/home/axel/mapping_l_oeuvre.json", 'w') do |f|
#   f.write mapping.to_json
# end

mapping = {}
File.open("/home/axel/l_oeuvre_tests/mapping_l_oeuvre.json") do |f|
  mapping = JSON.parse(f.read)
end

ids_query = "http://localhost:8983/solr/hydra-development/select?fl=id&q=has_model_ssim:Issue%20AND%20member_of_collection_ids_ssim:#{npid}&wt=json&rows=1000000"
processed_ids = JSON.parse(open(ids_query).read)['response']['docs'].map{|h| h['id']}
nbissues = Dir[all_metadata_path + "/*.json"].size


Dir.chdir(pxml_path)
Dir.glob('*').select do |f|
  File.directory? f
end.each_with_index do |dir_path, idx|
  dir_path = "#{pxml_path}/#{dir_path}"
  issue_id = "#{npid}_#{Dir["#{dir_path}/*.pxml"][0].split('/')[-1].split('_')[0..1].join('-')}"
  ark = "ark:/#{issue_id.split('_')[-1].gsub('-','/')}"
  if processed_ids.include? issue_id
    puts " issue %s already exists" % issue_id
    next
  end
  puts "Processing #{issue_id} ((#{idx+1} out of #{nbissues}))..."
  puts dir_path
  puts mapping[ark]
  puts ark
  #exit
  articles_to_save = []
  issue_all_text = []
  issue = Issue2.new
  issue.id = issue_id
  issue.newspaper_id = npid
  issue.original_uri = "https://gallica.bnf.fr/#{ark}"
  issue.title = mapping[ark][1]
  issue.date_created = mapping[ark][2]
  issue.nb_pages = Dir["#{dir_path}/*.pxml"].size
  issue.language = 'fr'
  issue.pages = []
  id_start_from = 0
  issue_manifest = {"sequences" => [{"canvases" => []}]}
  Dir["#{dir_path}/*.pxml"].sort.each_with_index do |pxml_path, idx|
    pfs = PageFileSet2.new
    pfs.page_number = idx + 1
    pfs.id = "#{issue.id}_page_#{idx+1}"
    pfs.language = 'fr'
    pfs.ocr_path = pxml_path
    pfs.iiif_url = (issue.original_uri + "/f#{pfs.page_number}").insert(issue.original_uri.index('ark:/'), 'iiif/')
    info_json_url = pfs.iiif_url + "/info.json"
    issue_manifest["sequences"][0]["canvases"] << {"images" => [{"resource" => {"service" => {"@id" => pfs.iiif_url}}}]}
    info_json = JSON.load(open(info_json_url))
    pfs.height = info_json['height'].to_i
    pfs.width = info_json['width'].to_i
    pfs.mime_type = 'image/jpeg'
    if idx == 0 # first page
      issue.thumbnail_url = "#{pfs.iiif_url}/full/,200/0/default.jpg"
    end

    myparser = MyParser.new issue.id, issue.date_created, issue.language, issue.newspaper_id, idx+1, id_start_from, pfs.width, pfs.height
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
  require 'nokogiri'
  require 'json'

  class MyParser < Nokogiri::XML::SAX::Document

    attr_accessor :articles, :page_all_text, :last_id, :id_start_from

    def initialize(issue_id, date_created, lang, npid, page, id_start_from, original_width, original_height)
      @issue_id = issue_id
      @date_created = date_created
      @language = lang
      @newspaper_id = npid
      @pagenum = page
      @id_start_from = id_start_from
      @last_id = id_start_from
      @original_width = original_width
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
        @image_width = at['imageWidth']
        @image_height = at['imageHeight']
        @image_ratio = @original_height.to_f / @image_height.to_f
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
        max_x = points.map(&:first).max
        max_y = points.map(&:last).max
        min_x = points.map(&:first).min
        min_y = points.map(&:last).min
        x = (min_x * @image_ratio).to_i
        y = (min_y * @image_ratio).to_i
        width = ((max_x - min_x) * @image_ratio).to_i
        height = ((max_y - min_y) * @image_ratio).to_i
        @articles[@current_article_id].canvases_parts << "#{Rails.configuration.newseye_services['host']}/iiif/#{@issue_id}/canvas/page_#{@pagenum}#xywh=#{x},#{y},#{width},#{height}"
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

  def map_dir_ark main_path
    mapping = {}
    total = Dir[main_path + "/*"].size
    Dir[main_path + "/*"].each_with_index do |issue_dir, idx|
      puts "Mapping #{idx+1} out of #{total}..."
      metadata_file = Dir["#{issue_dir}/manifest.xml"][0]
      metadata_file = File.open(metadata_file) do |f|
        Nokogiri::XML(f)
      end
      metadata_file.remove_namespaces!
      begin
        ark = metadata_file.xpath("/descendant::amdSec/descendant::object[@type='premis:representation']/descendant::objectIdentifierType[text()='ark']")[0].next_element.text
      rescue Exception => e
        puts "getting ark from OCR file"
        File.open("#{issue_dir}/ocr/X0000001.xml", 'r') do |ocr_file|
          ocr = Nokogiri::XML(ocr_file)
          ocr.remove_namespaces!
          ark = ocr.xpath("/alto/Description/sourceImageInformation/fileIdentifier").text
          ark = ark[0...ark.rindex('/')]
        end
      end
      title = metadata_file.xpath("/descendant::dmdSec[@ID='DMD.2']/descendant::spar_dc/title").text.to_s
      date_created = metadata_file.xpath("/descendant::dmdSec[@ID='DMD.2']/descendant::spar_dc/date").text.to_s
      mapping[ark] = [issue_dir, title, date_created]
      puts "#{ark}  --  #{issue_dir}"
    end
    mapping
  end
}
