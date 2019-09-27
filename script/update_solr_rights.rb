require 'json'
require 'open-uri'
require 'net/http'
require "active_support/core_ext/array"

ids_query = "http://localhost:8983/solr/hydra-development/select?fl=id&q=has_model_ssim:Issue&fq=-language_ssi:fi%20AND%20-language_ssi:se&wt=json&rows=1000000"
docs_ids = JSON.parse(open(ids_query).read)['response']['docs'].map{|h| h['id']}

docs_ids.in_groups_of(2, false).each do |doc_batch|
  puts "processing #{doc_batch}..."
  json_docs = []
  doc_batch.each do |doc_id|
    puts doc_id
    json_doc = {}
    json_doc['id'] = doc_id
    json_doc['discover_access_group_ssim'] = {add: 'registered'}
    json_doc['read_access_group_ssim'] = {add: 'registered'}
    json_docs << json_doc

    article_ids_query = "http://localhost:8983/solr/hydra-development/select?fl=id&q=has_model_ssim:Article%20AND%20from_issue_ssi:#{doc_id}&wt=json&rows=1000000"
    articles_ids = JSON.parse(open(article_ids_query).read)['response']['docs'].map{|h| h['id']}
    articles_ids.each do |article_id|
      json_doc = {}
      json_doc['id'] = article_id
      json_doc['discover_access_group_ssim'] = {add: 'registered'}
      json_doc['read_access_group_ssim'] = {add: 'registered'}
      json_docs << json_doc
    end
  end
  json_docs = json_docs.map{ |jd| "\"add\": {\"doc\": #{jd.to_json} }" }
  data = "{#{json_docs.join(",")}}"
  commit_uri = URI.parse("http://localhost:8983/solr/hydra-development/update?commit=true")
  uri = URI.parse("http://localhost:8983/solr/hydra-development/update")
  header = {'Content-Type': 'application/json'}
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.request_uri, header)
  request.body = data
  puts http.request(request)
  puts http.request(Net::HTTP::Get.new(commit_uri.request_uri, header))
end