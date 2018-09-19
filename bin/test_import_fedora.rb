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

  i = 1
  continue = true
  while continue
    begin
      ocr_file = open('https://digi.kansalliskirjasto.fi/sanomalehti/binding/%s/page-%i.xml' % [id, i], 'r')
      ocr = Nokogiri::XML(open(ocr_file).read, 'UTF-8')
      puts 'adding page %{num}' % [num: i]
      ocr_text = ''
      for line in ocr.xpath('//TextLine')
        for word in line.xpath('./String')
          ocr_text += word['CONTENT'] + ' '
        end
        ocr_text.strip!
        ocr_text += "\n"
      end
      ocr_text.strip!
      image_full = open('https://digi.kansalliskirjasto.fi/sanomalehti/binding/%s/image/%i' % [id, i], 'r')
      image_thumbnail = open('https://digi.kansalliskirjasto.fi/sanomalehti/binding/%s/thumbnail/%i' % [id, i], 'r')
      ifs = PageFileSet.new
      ifs.id = '%{id}_ifs_%{num}' % [id: id, num: i]
      ifs.page_number = i
      # Hydra::Works::AddFileToFileSet.call(ifs, image_full, :image_full)
      # Hydra::Works::AddFileToFileSet.call(ifs, image_thumbnail, :thumbnail)
      # begin
      #   Hydra::Works::AddFileToFileSet.call(ifs, ocr, :alto)
      # rescue Exception => e
      #   puts e
      # end

      Hydra::Works::UploadFileToFileSet.call(ifs, image_full)
      # Hydra::Works::AddFileToFileSet.call(ifs, image_thumbnail, :thumbnail)
      # Hydra::Works::AddFileToFileSet.call(ifs, ocr_text, :extracted_text)
      ifs.build_extracted_text
      ifs.extracted_text.content = ocr_text
      ifs.save
      np.members << ifs
      np.thumbnail_url = 'https://digi.kansalliskirjasto.fi/sanomalehti/binding/%s/thumbnail/%i' % [id, i] if i == 1
      np.save
      puts 'thumb' if i == 1
      i += 1
    rescue OpenURI::HTTPError
      continue = false
    end
  end
  np.nb_pages = i
  np.all_text = np.members.each.to_a.map{|x| x.extracted_text.content.force_encoding('UTF-8')}.join("\n")
  np.save
  coll.members << np unless coll.members.include? np
end




