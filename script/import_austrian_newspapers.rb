require 'logger'
require 'json'
require 'nokogiri'
require 'open-uri'

# current_np = "nfp" # krz, ibn, aze
# years = Array(1864..1873) + Array(1895..1900) + Array(1911..1922) + Array(1933..1939)

# current_np = "ibn"
# years = Array(1864..1873) + Array(1895..1900) + Array(1911..1922) + Array(1933..1945)
#
# current_np = "krz"
# years = Array(1911..1922) + Array(1933..1944)
#
current_np = "aze"
years = Array(1895..1900) + Array(1911..1922) + Array(1933..1937)

issues_ids = []
years.each do |y|
  ('01'..'12').each do |m|
    ('01'..'31').each do |d|
      issues_ids << "#{y}#{m}#{d}"
    end
  end
end

logger = Logger.new MultiIO.new(STDOUT, File.new("/home/axel/Nextcloud/NewsEye/data/import_#{current_np}.log", 'a'))
failed_path = "/home/axel/Nextcloud/NewsEye/data/failed_#{current_np}.txt"

output_path = "/home/axel/Nextcloud/NewsEye/data/import_#{current_np}"
begin
  Dir.mkdir output_path
  logger.info "creating directory #{output_path}"
rescue
  logger.info "using directory #{output_path}"
end

already_processed = Dir.glob("#{output_path}/*.json")

already_processed.map! { |f| f[f.rindex('/')+4..-6] }
nb_processed = already_processed.size
#already_processed.map! { |f| f[6..-6] }

logger.info "starting new import session"

nb_issues = issues_ids.size
issues_ids = issues_ids - already_processed
issues_ids.each_with_index do |issue_id, issue_index|
  begin
    logger.info "importing issue #{issue_id}, #{issue_index+nb_processed+1} out of #{nb_issues} (#{(((issue_index+nb_processed+1)/nb_issues.to_f)*100).round(2)}%)"
    if already_processed.include? issue_id
      logger.info "#{issue_id} already processed"
      next
    end
    url = "https://iiif-auth.onb.ac.at/presentation/ANNO/#{current_np}#{issue_id}/manifest"
    logger.info "Downloading #{url}"
    manifest = JSON.parse(open(url, http_basic_authentication: ['newseye','TIrl1wwNf19nmGjcnSmo']).read)

    output_issue = {}
    output_issue['original_uri'] = manifest['seeAlso'].find{ |sa| sa['@id'].start_with? 'http://anno.onb.ac.at/cgi-content/anno?' }['@id']
    output_issue['id'] = "#{current_np}#{issue_id}"
    output_issue['date_created'] = "#{issue_id[0..3]}-#{issue_id[4..5]}-#{issue_id[6..7]}-"
    output_issue['title'] = manifest['label']
    output_issue['language'] = manifest['metadata'].find do |md|
      md['label'].include?({"@value": "Languages", "@language": "en"}.inject({}){|memo,(k,v)| memo[k.to_s] = v; memo})
    end['value']
    output_issue['location'] = manifest['metadata'].find do |md|
      md['label'].include?({"@value": "Place of Publications", "@language": "en"}.inject({}){|memo,(k,v)| memo[k.to_s] = v; memo})
    end['value']

    num_page = manifest['sequences'][0]['canvases'].size
    output_issue['nb_pages'] = num_page
    output_issue['pages'] = []
    (1..num_page).each do |i|
      begin
        logger.info "importing page #{i} out of #{num_page}"
        output_page = {}
        output_page['id'] = "#{current_np}#{issue_id}_page_#{i}"
        output_page['page_number'] = i
        output_page['ocr_path'] = "/db/seeds_data/#{output_page['id']}.xml"
        output_issue['pages'] << output_page
        ocr_url = "https://iiif-auth.onb.ac.at/presentation/ANNO/#{current_np}#{issue_id}/resource/#{i.to_s.rjust(8, '0')}.xml"
        ocr_file = open(ocr_url, 'r', http_basic_authentication: ['newseye','TIrl1wwNf19nmGjcnSmo'])
        FileUtils.cp(ocr_file.path, "#{output_path}/#{output_page['id']}.xml")
      rescue Exception => e
        logger.error "page #{output_page['id']} import failed"
        # logger.error e
        File.open(failed_path, 'a') { |f| f.write("#{output_page['id']}\n") }
      end
    end
    logger.info "Saving issue #{output_issue['id']}"
    File.open("#{output_path}/#{output_issue['id']}.json", 'w') do |of|
      of.write JSON.pretty_generate(output_issue)
    end
  rescue OpenURI::HTTPError => e
    logger.error "issue does not exist #{issue_id}"
    File.open("#{output_path}/#{current_np}#{issue_id}.json", 'w') do |of|
      of.write "#{url} does not exist"
    end
  rescue Exception => e
    logger.error "there was a problem while importing issue #{issue_id}"
    logger.error e
  end
end


BEGIN{
  class MultiIO
    def initialize(*targets)
      @targets = targets
    end

    def write(*args)
      @targets.each {|t| t.write(*args)}
    end

    def close
      @targets.each(&:close)
    end
  end
}