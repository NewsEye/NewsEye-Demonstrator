#!/usr/bin/env ruby

require 'pp'
require 'europeana/api'
require 'nokogiri'
require 'open-uri'

Europeana::API.api_key = 'dMFAkBgyx'

search = Europeana::API.search(query: 'europeana_collectionName:92*ewspapers* AND COUNTRY:finland', rows: 10)

puts 'adding collection'
coll = Newspaper.new
coll.id = 'np1'
coll.title = 'Keski-Suomi'
coll.save

for item in search[:items] do
  pp 'ITEM ' + item[:id]
  record = Europeana::API.record(item[:id])
  proxy = record[:object][:proxies].select do |proxy|
    proxy[:about].include? '/proxy/provider'
  end
  url = proxy[0][:dcIdentifier][:def][0]
  id = url[url.rindex('/') + 1..-1]
  pp id
  pp url

  doc = Nokogiri::XML(open('https://digi.kansalliskirjasto.fi/interfaces/OAI-PMH?verb=GetRecord&metadataPrefix=oai_dc&identifier=oai:null:%s' % id).read)
  doc.remove_namespaces!
  md_date = doc.xpath('//metadata//date').text
  md_description = doc.xpath('//metadata//description/text()').map { |it| it.text }
  md_title = doc.xpath('//metadata//title').text
  md_contributor = doc.xpath('//metadata//contributor/text()').map { |it| it.text }
  md_publisher = doc.xpath('//metadata//publisher').text
  md_language = doc.xpath('//metadata//language/text()').map { |it| it.text }
  md_type = doc.xpath('//metadata//type/text()').map { |it| it.text }

  puts 'adding issue'
  np = Issue.new
  np.id = id
  np.title = md_title
  np.date_created = md_date
  np.publisher = md_publisher
  np.original_uri = url
  np.language = md_language[0]
  #np.description = md_description
  np.nb_pages = 4
# np.text_content = issue_text

  i = 1
  continue = true
  while continue
    begin
      ocr = 'https://digi.kansalliskirjasto.fi/sanomalehti/binding/%s/page-%i.xml' % [id, i]
      Nokogiri::XML(open(ocr).read)
      image_full = 'https://digi.kansalliskirjasto.fi/sanomalehti/binding/%s/image/%i' % [id, i]
      image_thumbnail = 'https://digi.kansalliskirjasto.fi/sanomalehti/binding/%s/thumbnail/%i' % [id, i]
      puts 'adding page %{num}' % [num: i]
      ifs = PageFileSet.new
      ifs.id = '%{id}_ifs_%{num}' % [id: id, num: i]
      ifs.page_number = i
      Hydra::Works::AddExternalFileToFileSet.call(ifs, ocr, :extracted_text)
      Hydra::Works::AddExternalFileToFileSet.call(ifs, image_full, :original_file)
      Hydra::Works::AddExternalFileToFileSet.call(ifs, image_thumbnail, :thumbnail)
      ifs.save
      np.members << ifs
      np.thumbnail_url = image_thumbnail if i == 1
      np.save
      puts 'thumb' if i == 1
      i += 1
    rescue OpenURI::HTTPError
      continue = false
    end
  end
  np.nb_pages = i
  np.save
  coll.members << np unless coll.members.include? np
end




