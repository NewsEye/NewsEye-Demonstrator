require 'logger'
require 'json'
require 'nokogiri'
require 'open-uri'

current_np = "l_oeuvre"
logger = Logger.new MultiIO.new(STDOUT, File.new("/home/axel/Nextcloud/NewsEye/data/import_#{current_np}.log", 'a'))
failed_path = "/home/axel/Nextcloud/NewsEye/data/failed.txt"

output_path = "/home/axel/Nextcloud/NewsEye/data/import_#{current_np}"
begin
  Dir.mkdir output_path
  logger.info "creating directory #{output_path}"
rescue
  logger.info "using directory #{output_path}"
end

already_processed = Dir.glob("#{output_path}/*.json")

already_processed.map! { |f| f[f.rindex('/')+7..-6] }
nb_processed = already_processed.size
#already_processed.map! { |f| f[6..-6] }

logger.info "starting new import session"

arks = open("/home/axel/Nextcloud/NewsEye/data/bnf_#{current_np}.txt", 'r').read.split("\n")
nb_arks = arks.size
arks = arks - already_processed
arks.each_with_index do |ark, arkindex|
  begin
    logger.info "importing issue #{ark}, #{arkindex+nb_processed+1} out of #{nb_arks} (#{(((arkindex+nb_processed+1)/nb_arks.to_f)*100).round(2)}%)"
    if already_processed.include? ark
      logger.info "#{ark} already processed"
      next
    end
    ark = "12148/#{ark}"
    output_issue = {}
    output_issue['original_uri'] = "https://gallica.bnf.fr/ark:/#{ark}"
    output_issue['id'] = ark.sub('/', '-')
    metadata_doc = Nokogiri::XML(open('https://gallica.bnf.fr/services/OAIRecord?ark=%s' % ark[ark.rindex('/')+1..-1]).read)
    metadata_doc.remove_namespaces!
    output_issue['date_created'] = metadata_doc.xpath('//metadata//date').text
    output_issue['title'] = metadata_doc.xpath('//metadata//title').text
    output_issue['publisher'] = metadata_doc.xpath('//metadata//publisher').text
    output_issue['contributor'] = metadata_doc.xpath('//metadata//contributor').text
    output_issue['language'] = "fr"

    pagination_doc = Nokogiri::XML(open('http://gallica.bnf.fr/services/Pagination?ark=%s' % ark[ark.rindex('/')+1..-1]).read)
    num_page = pagination_doc.xpath('//page').size
    output_issue['nb_pages'] = num_page
    output_issue['pages'] = []
    (1..num_page).each do |i|
      begin
        logger.info "importing page #{i} out of #{num_page}"
        output_page = {}
        output_page['id'] = "#{ark.sub('/', '-')}_page_#{i}"
        output_page['page_number'] = i
        output_page['ocr_path'] = "/db/seeds_data/#{output_page['id']}.xml"
        ocr_url = 'https://gallica.bnf.fr/RequestDigitalElement?O=%{ark}&E=ALTO&Deb=%{page}' % [ark: ark[ark.rindex('/')+1..-1], page: i]
        ocr_file = open(ocr_url, 'r')
        FileUtils.cp(ocr_file.path, "#{output_path}/#{output_page['id']}.xml")
        output_issue['pages'] << output_page
      rescue Exception => e
        logger.error "page #{output_page['id']} import failed"
        # logger.error e
        File.open(failed_path, 'a') { |f| f.write("") }
      end
    end
    logger.info "Saving issue #{output_issue['id']}"
    File.open("#{output_path}/#{output_issue['id']}.json", 'w') do |of|
      of.write JSON.pretty_generate(output_issue)
    end
  rescue Exception => e
    logger.error "there was a problem while importing issue #{ark}"
    logger.error e
  end
end



# require 'nokogiri'
# require 'open-uri'
#
# File.open("/home/axel/Nextcloud/NewsEye/data/bnf_l_oeuvre.txt", 'w') do |f|
#
#   # la_presse = 'ark:/12148/cb34448033b/date'
#   # (1850..1890).each do |year|
#   #   puts year
#   #   issues = Nokogiri::XML(open("https://gallica.bnf.fr/services/Issues?ark=#{la_presse}&date=#{year}"))
#   #   issues.xpath('//issue').each do |issue|
#   #     f.write(issue['ark']+"\n")
#   #   end
#   # end
#
#   # le_matin = 'ark:/12148/cb328123058/date'
#   # (1884..1944).each do |year|
#   #   puts year
#   #   issues = Nokogiri::XML(open("https://gallica.bnf.fr/services/Issues?ark=#{le_matin}&date=#{year}"))
#   #   issues.xpath('//issue').each do |issue|
#   #     f.write(issue['ark']+"\n")
#   #   end
#   # end
#
#   # le_gaulois = 'ark:/12148/cb32779904b/date'
#   # (1868..1900).each do |year|
#   #   puts year
#   #   issues = Nokogiri::XML(open("https://gallica.bnf.fr/services/Issues?ark=#{le_gaulois}&date=#{year}"))
#   #   issues.xpath('//issue').each do |issue|
#   #     f.write(issue['ark']+"\n")
#   #   end
#   # end
#
#   # la_fronde = 'ark:/12148/cb327788531/date'
#   # (1897..1929).each do |year|
#   #   puts year
#   #   begin
#   #     issues = Nokogiri::XML(open("https://gallica.bnf.fr/services/Issues?ark=#{la_fronde}&date=#{year}"))
#   #     issues.xpath('//issue').each do |issue|
#   #       f.write(issue['ark']+"\n")
#   #     end
#   #   rescue
#   #   end
#   #   end
#
#   # marie_claire = 'ark:/12148/cb343488519/date'
#   # (1937..1944).each do |year|
#   #   puts year
#   #   begin
#   #   issues = Nokogiri::XML(open("https://gallica.bnf.fr/services/Issues?ark=#{marie_claire}&date=#{year}"))
#   #   issues.xpath('//issue').each do |issue|
#   #     f.write(issue['ark']+"\n")
#   #   end
#   #   rescue
#   #   end
#   # end
#
#   l_oeuvre = 'ark:/12148/cb34429265b/date'
#   (1915..1944).each do |year|
#     puts year
#     begin
#     issues = Nokogiri::XML(open("https://gallica.bnf.fr/services/Issues?ark=#{l_oeuvre}&date=#{year}"))
#     issues.xpath('//issue').each do |issue|
#       f.write(issue['ark']+"\n")
#     end
#     rescue
#     end
#   end
#
# end

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