require 'logger'
require 'json'
require 'nokogiri'
require 'open-uri'

current_np = "1457-4705"
logger = Logger.new MultiIO.new(STDOUT, File.new("/home/axel/NLF_data/import_#{current_np}.log", 'a'))
failed_path = "/home/axel/NLF_data/failed_#{current_np}.txt"

output_path = "/home/axel/NLF_data/import_#{current_np}"
begin
  Dir.mkdir output_path
  logger.info "creating directory #{output_path}"
rescue
  logger.info "using directory #{output_path}"
end

already_processed = Dir.glob("#{output_path}/*.json")

already_processed.map! { |f| f[f.rindex('/')+current_np.size+1..-6] }
nb_processed = already_processed.size
#already_processed.map! { |f| f[6..-6] }

logger.info "starting new import session"

bindings_ids = open("/home/axel/NLF_data/nlf_#{current_np}.txt", 'r').read.split("\n")
nb_bindings = bindings_ids.size
bindings_ids = bindings_ids - already_processed
bindings_ids.each_with_index do |binding_id, binding_index|
  begin
    logger.info "importing issue #{binding_id}, #{binding_index+nb_processed+1} out of #{nb_bindings} (#{(((binding_index+nb_processed+1)/nb_bindings.to_f)*100).round(2)}%)"
    if already_processed.include? binding_id
      logger.info "#{binding_id} already processed"
      next
    end
    output_issue = {}
    output_issue['original_uri'] = "https://digi.kansalliskirjasto.fi/sanomalehti/binding/#{binding_id}"
    output_issue['id'] = "#{current_np}#{binding_id}"
    metadata_doc = Nokogiri::XML(open("https://digi.kansalliskirjasto.fi/interfaces/OAI-PMH?verb=GetRecord&metadataPrefix=oai_dc&identifier=oai:null:#{binding_id}").read)
    metadata_doc.remove_namespaces!
    output_issue['date_created'] = metadata_doc.xpath('//metadata//date').text
    output_issue['title'] = metadata_doc.xpath('//metadata//title').text
    output_issue['publisher'] = metadata_doc.xpath('//metadata//publisher').text
    output_issue['contributor'] = metadata_doc.xpath('//metadata//contributor').text
    output_issue['language'] = metadata_doc.xpath('//metadata//language').text
    output_issue['location'] = metadata_doc.xpath('//metadata//coverage').text
    output_issue['pages'] = []

    pages_left = true
    page_number = 1
    while pages_left do
      begin
        image_data, thumbnail_data, ocr_data = nil
        image_url = "https://digi.kansalliskirjasto.fi/sanomalehti/binding/#{binding_id}/image/#{page_number}"
        thumbnail_url = "https://digi.kansalliskirjasto.fi/sanomalehti/binding/#{binding_id}/thumbnail/#{page_number}"
        ocr_url = "https://digi.kansalliskirjasto.fi/sanomalehti/binding/#{binding_id}/page-#{page_number}.xml"
        image_data = open(image_url)
        thumbnail_data = open(thumbnail_url)
        ocr_data = open(ocr_url)

        pages_left =
            logger.info "importing page #{page_number}"
        output_page = {}
        output_page['id'] = "#{binding_id}_page_#{page_number}"
        output_page['page_number'] = page_number
        output_page['ocr_path'] = "/db/seeds_data/#{output_page['id']}.xml"
        output_issue['pages'] << output_page

        FileUtils.cp(image_data, "#{output_path}/#{current_np}#{binding_id}_page_#{page_number}.jpg")
        FileUtils.cp(ocr_data, "#{output_path}/#{current_np}#{binding_id}_page_#{page_number}.xml")

        page_number += 1
      rescue
        logger.info "no more pages"
        pages_left = false
      end
    end
    output_issue['nb_pages'] = page_number
    logger.info "Saving issue #{output_issue['id']}"
    File.open("#{output_path}/#{output_issue['id']}.json", 'w') do |of|
      of.write JSON.pretty_generate(output_issue)
    end
  rescue Exception => e
    logger.error "there was a problem while importing issue #{binding_id}"
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
