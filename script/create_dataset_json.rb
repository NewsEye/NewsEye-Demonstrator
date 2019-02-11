#!/usr/bin/env ruby

require 'pp'
require 'europeana/api'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'fileutils'

Europeana::API.key = 'LF3MuoE5h'

# output_dir = File.join(File.dirname(__FILE__), 'seeds_data/')
output_dir = '/db/seeds_data/'
output = []

## Newspaper record
# NLF

# record = Europeana::API.record('/9200301/BibliographicResource_3000055252516')
#
# pp "Adding newspaper %s" % record[:object][:title][0]
# np = {}
# np[:title] = record[:object][:title][0]
# np[:publisher] = record[:object][:proxies][0][:dcPublisher][:def][0]
# np[:language] = record[:object][:proxies][0][:dcLanguage][:def][0]
# np[:datefrom] = record[:object][:proxies][0][:dctermsIssued][:def][0]
# np[:dateto] = record[:object][:proxies][0][:dctermsIssued][:def][0]
# np[:location] = record[:object][:proxies][0][:dctermsSpatial][:def][0]
#
# np[:issues] = []
#
# # iterate issues of this newspaper
# record[:object][:proxies][0][:dctermsHasPart][:def].each_with_index do |issue_link, i|
#   next if i != 1 and i != 4 and i != 5
#
#   issue = {}
#
#   europeana_id = '/' + issue_link.split('/')[-2..-1].join('/')
#   pp "Adding issue %s" % europeana_id
#   issue_record = Europeana::API.record(europeana_id)
#   proxy = issue_record[:object][:proxies].select do |proxy|
#     proxy[:about].include? '/proxy/provider'
#   end
#   issue[:original_uri] = proxy[0][:dcIdentifier][:def][0]
#   issue[:id] = issue[:original_uri][issue[:original_uri].rindex('/') + 1..-1]
#   issue[:publisher] = proxy[0][:dcPublisher][:def][0]
#   issue[:title] = proxy[0][:dcTitle][:def][0]
#   issue[:date_created] = proxy[0][:dctermsIssued][:def][0]
#   issue[:language] = proxy[0][:dcLanguage][:def][0]
#   issue[:nb_pages] = proxy[0][:dctermsExtent][:en][0].split(':')[1].strip.to_i
#   issue[:thumbnail_url] = 'https://digi.kansalliskirjasto.fi/sanomalehti/binding/%s/thumbnail/1' % issue[:id]
#   issue[:pages] = []
#
#   for pagenum in 1..issue[:nb_pages] do
#     pp "Adding page %i out of %i" % [pagenum, issue[:nb_pages]]
#
#     pfs = {}
#     pfs[:id] = '%{id}_page_%{num}' % [id: issue[:id], num: pagenum]
#     pfs[:page_number] = pagenum
#     pfs[:image_path] = output_dir + pfs[:id] + '.jpg'
#     pfs[:ocr_path] = output_dir + pfs[:id] + '.xml'
#     ocr_file = open('https://digi.kansalliskirjasto.fi/sanomalehti/binding/%s/page-%i.xml' % [issue[:id], pagenum], 'r')
#     FileUtils.cp(ocr_file.path, '..' + pfs[:ocr_path])
#     image_full = open('https://digi.kansalliskirjasto.fi/sanomalehti/binding/%s/image/%i' % [issue[:id], pagenum], 'r')
#     FileUtils.cp(image_full.path, '..' + pfs[:image_path])
#     issue[:pages] << pfs
#   end
#   np[:issues] << issue
# end
#
# output << np

#####################################################################
# BNF

record = Europeana::API.record('/9200408/BibliographicResource_3000113889387')

pp "Adding newspaper %s" % record[:object][:title][0]
np = {}
np[:title] = record[:object][:title][0]
#np[:publisher] = record[:object][:proxies][0][:dcPublisher][:def][0]
np[:language] = record[:object][:proxies][0][:dcLanguage][:def][0]
np[:datefrom] = record[:object][:proxies][0][:dctermsIssued][:def][0]
np[:dateto] = record[:object][:proxies][0][:dctermsIssued][:def][0]
#np[:location] = record[:object][:proxies][0][:dctermsSpatial][:def][0]

np[:issues] = []

# iterate issues of this newspaper
record[:object][:proxies][0][:dctermsHasPart][:def].each_with_index do |issue_link, i|
  next if i != 1 and i != 4 and i != 5

  issue = {}

  europeana_id = '/' + issue_link.split('/').last(2).join('/')
  pp "Adding issue %s" % europeana_id
  issue_record = Europeana::API.record(europeana_id)
  proxy = issue_record[:object][:proxies].select do |proxy|
    proxy[:about].include? '/proxy/provider'
  end
  issue[:original_uri] = proxy[0][:dcIdentifier][:def][0]
  issue[:id] = issue[:original_uri].split('/').last(2).join('-')
  issue[:publisher] = proxy[0][:dcPublisher][:def][0]
  issue[:title] = proxy[0][:dcTitle][:def][0]
  issue[:date_created] = proxy[0][:dctermsIssued][:def][0]
  issue[:language] = proxy[0][:dcLanguage][:def][0]
  issue[:nb_pages] = proxy[0][:dctermsExtent][:en][0].split(':')[1].strip.to_i
  issue[:thumbnail_url] = 'https://gallica.bnf.fr/ark:/%{ark}/thumbnail' % [ark: issue[:id].sub('-', '/'), page: i]
  issue[:pages] = []


  for pagenum in 1..issue[:nb_pages] do
    pp "Adding page %i out of %i" % [pagenum, issue[:nb_pages]]

    pfs = {}
    pfs[:id] = '%{id}_page_%{num}' % [id: issue[:id], num: pagenum]
    pfs[:page_number] = pagenum
    pfs[:image_path] = output_dir + pfs[:id] + '.jpg'
    pfs[:ocr_path] = output_dir + pfs[:id] + '.xml'
    ocr_url = 'https://gallica.bnf.fr/RequestDigitalElement?O=%{ark}&E=ALTO&Deb=%{page}' % [ark: issue[:id].split('-')[1], page: pagenum]
    ocr_file = open(ocr_url, 'r')
    FileUtils.cp(ocr_file.path, '..' + pfs[:ocr_path])
    img_url = 'https://gallica.bnf.fr/iiif/ark:/%{ark}/f%{page}/full/full/0/native.jpg' % [ark: issue[:id].sub('-', '/'), page: pagenum]
    image_full = open(img_url, 'r')
    FileUtils.cp(image_full.path, '..' + pfs[:image_path])
    issue[:pages] << pfs
  end
  np[:issues] << issue
end

output << np
File.open(File.join(File.dirname(__FILE__),  '..' + output_dir) + 'data.json', 'w') do |f|
  f.write(JSON.pretty_generate(output))
end


# Le Figaro : /9200408/BibliographicResource_3000113889387
# Keski-Suomi : /9200301/BibliographicResource_3000055252516