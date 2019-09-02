require 'open-uri'
require 'json'

output_dir = "/home/axel/data_export"

newspaper_title = "l_oeuvre"

rows = 1
start = 0
fl = "id,all_text_tfr_siv"
total = 0
loop do
  puts "#{total} documents were imported"
  url = "http://localhost:8983/solr/hydra-development/select?q=has_model_ssim:Issue%20member_of_collection_ids_ssim:#{newspaper_title}*&fl=#{fl}&rows=#{rows}&start=#{start}"
  response = JSON.parse(open(url).read)['response']
  num_found = response['numFound']
  response['docs'].each do |doc|
    file = File.open("#{output_dir}/#{doc['id']}.json", 'w')
    file.write(doc['all_text_tfr_siv'])
    file.close
    total += 1
  end
  start += rows
  break unless start < num_found
end



# url = "http://localhost:8983/solr/hydra-development/select?q=has_model_ssim:Issue%20member_of_collection_ids_ssim:#{newspaper_title}*&fl=#{fl}&rows=#{rows}&start=#{start}"
# response = JSON.parse(open(url).read)['response']
# num_found = response['numFound']
# response['docs'].each do |doc|
#   file = File.open("#{output_dir}/#{doc['id']}.json", 'w')
#   file.write(doc['all_text_tfr_siv'])
#   file.close
# end
# start += rows
#
# while start < num_found
#   url = "http://localhost:8983/solr/hydra-development/select?q=has_model_ssim:Issue%20member_of_collection_ids_ssim:#{newspaper_title}*&fl=#{fl}&rows=#{rows}&start=#{start}"
#   response = JSON.parse(open(url).read)['response']
#   num_found = response['numFound']
#   response['docs'].each do |doc|
#     file = File.open("#{output_dir}/#{doc['id']}.json", 'w')
#     file.write(doc['all_text_tfr_siv'])
#     file.close
#   end
#   start += rows
# end