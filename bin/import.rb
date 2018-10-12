#!/usr/bin/env ruby

require 'pp'
require 'europeana/api'
require 'nokogiri'
require 'open-uri'

Europeana::API.api_key = 'dMFAkBgyx'



# Gallica
# record['object']['proxies'][0][dcSource]
# ocr : https://gallica.bnf.fr/RequestDigitalElement?O=[id]&E=ALTO&Deb=[page]
# metadata : https://gallica.bnf.fr/services/OAIRecord?ark=ark:/12148/bpt6k5773155v
# iiif : https://github.com/hackathonBnF/hackathon2016/wiki/API-IIIF
# https://gallica.bnf.fr/iiif/ark:/12148/bpt6k296177k/manifest.json

# NLF
# record['object']['proxies'][0][dcSource]
# https://digi.kansalliskirjasto.fi/sanomalehti/binding/[ID]
# metadata : https://digi.kansalliskirjasto.fi/interfaces/OAI-PMH?verb=GetRecord&metadataPrefix=oai_dc&identifier=oai:null:[ID]

# ONB
# record['object']['proxies'][0][dcIdentifier]

# issue = Issue.new
# #issue.id = ActiveFedora::Noid::Service.new.mint
# issue.apply_depositor_metadata('axel.jeancaurant@gmail.com')
# issue.attributes = {title: ['ttestitre'], date_created: ['25/02/1934']}
# issue.visibility = Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
# Collection.where(title: 'Figaro').take.members << issue
# default_admin_set_id = AdminSet.find_or_create_default_admin_set_id
# default_admin_set = AdminSet.find(default_admin_set_id)
# issue.admin_set = default_admin_set
# issue.set_edit_groups(["content-admin"],[])
# issue.save

### BNF ################################################
# search = Europeana::API.search(query: 'europeana_collectionName:92*ewspapers* AND COUNTRY:france', rows: 10)
# for item in search[:items] do
#   pp 'ITEM ' + item[:id]
#   record = Europeana::API.record(item[:id])
#   proxy = record[:object][:proxies].select do |proxy|
#     proxy[:about].include? '/proxy/provider'
#   end
#   # get metadata
#   ark = proxy[0][:dcIdentifier][:def][0][/ark:.*/]
#   pp ark
#   doc = Nokogiri::XML(open('https://gallica.bnf.fr/services/OAIRecord?ark=%s' % ark).read)
#   doc.remove_namespaces!
#   md_date = doc.xpath('//metadata//date').text
#   md_description = doc.xpath('//metadata//description/text()').map { |it| it.text }
#   md_title = doc.xpath('//metadata//title').text
#   md_contributor = doc.xpath('//metadata//contributor/text()').map { |it| it.text }
#   md_publisher = doc.xpath('//metadata//publisher').text
#   md_language = doc.xpath('//metadata//language/text()').map { |it| it.text }
#   md_type = doc.xpath('//metadata//type/text()').map { |it| it.text }
#   pp md_date
#   pp md_description
#   pp md_contributor
#   pp md_publisher
#   pp md_title
#   pp md_language
#   pp md_type
#
#   # get pagination
#   doc = Nokogiri::XML(open('http://gallica.bnf.fr/services/Pagination?ark=%s' % ark[ark.rindex('/')+1..-1]).read)
#   num_page = doc.xpath('//page').size
#   (1..num_page).each do |i|
#     image_full = 'https://gallica.bnf.fr/iiif/%{ark}/f%{page}/full/full/0/native.jpg' % [ark: ark, page: i]
#     image_thumbnail = 'https://gallica.bnf.fr/%{ark}/f%{page}.thumbnail' % [ark: ark, page: i]
#     ocr = 'https://gallica.bnf.fr/RequestDigitalElement?O=%{ark}&E=ALTO&Deb=%{page}' % [ark: ark, page: i]
#     pp image_full
#     pp image_thumbnail
#     pp ocr
#   end
#   break
# end

########################################################

### NLF ################################################
search = Europeana::API.search(query: 'europeana_collectionName:92*ewspapers* AND COUNTRY:finland', rows: 10)
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
  pp md_date
  pp md_description
  pp md_contributor
  pp md_publisher
  pp md_title
  pp md_language
  pp md_type

  i = 1
  continue = true
  while continue
    begin
      ocr = 'https://digi.kansalliskirjasto.fi/sanomalehti/binding/%s/page-%i.xml' % [id, i]
      Nokogiri::XML(open(ocr).read)
      image_full = 'https://digi.kansalliskirjasto.fi/sanomalehti/binding/%s/image/%i' % [id, i]
      image_thumbnail = 'https://digi.kansalliskirjasto.fi/sanomalehti/binding/%s/thumbnail/%i' % [id, i]
      pp ocr
      pp image_full
      pp image_thumbnail
      i += 1
    rescue OpenURI::HTTPError
      continue = false
    end
  end
  #   # get pagination
  #   doc = Nokogiri::XML(open('http://gallica.bnf.fr/services/Pagination?ark=%s' % ark[ark.rindex('/')+1..-1]).read)
  #   num_page = doc.xpath('//page').size
  #   (1..num_page).each do |i|
  #     image_full = 'https://gallica.bnf.fr/iiif/%{ark}/f%{page}/full/full/0/native.jpg' % [ark: ark, page: i]
  #     image_thumbnail = 'https://gallica.bnf.fr/%{ark}/f%{page}.thumbnail' % [ark: ark, page: i]
  #     ocr = 'https://gallica.bnf.fr/RequestDigitalElement?O=%{ark}&E=ALTO&Deb=%{page}' % [ark: ark, page: i]
  #     pp image_full
  #     pp image_thumbnail
  #     pp ocr
  #   end
  break
end