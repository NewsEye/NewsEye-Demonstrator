require 'net/http'
require 'uri'
require 'json'

def get_auth_token
  uri = URI.parse("https://platform.newseye.eu/authenticate")
  header = {'Content-Type': 'application/json'}
  user = {
      email: 'r1@univ.com',
      password: 'password'
  }
# Create the HTTP objects
  http = Net::HTTP.new(uri.host, uri.port)
  request = Net::HTTP::Post.new(uri.request_uri, header)
  request.body = user.to_json
# Send the request
  http.use_ssl = true
  response = http.request(request)
  JSON.parse(response.body)['auth_token']
end

def query
  header = {'Content-Type': 'application/json', 'Authorization': get_auth_token}
  (1..36).each do |i|
    puts i
    url = URI.parse "https://platform.newseye.eu/fr/catalog.json?f[member_of_collection_ids_ssim][]=arbeiter_zeitung&rows=100&page=#{i}"
    req = Net::HTTP::Get.new(url.to_s, header)
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    res = http.request(req)
    file = File.open("/home/axel/Téléchargements/catalog(#{i}).json", 'w')
    file.write(res.body)
    file.close
  end
end

# query

# def parse_catalog_json2
#   outdir = "/home/axel/Téléchargements/german_texts/"
#   file = "/home/axel/Téléchargements/catalog.json"
#   data = JSON.parse(File.read(file))
#   puts data['response']['docs'].size
#   data['response']['docs'].each do |doc|
#     id = doc['id']
#     text = doc['all_text_tde_siv']
#     puts id
#     file = File.open("#{outdir}#{id}.txt", 'w')
#     file.write(text)
#     file.close
#   end
# end
#
def parse_catalog_json
  outdir = "/home/axel/Téléchargements/german_texts/"
  (1..36).each do |i|
    file = "/home/axel/Téléchargements/catalog(#{i}).json"
    data = JSON.parse(File.read(file))
    data['response']['docs'].each do |doc|
      id = doc['id']
      text = doc['all_text_tde_siv']
      puts id
      file = File.open("#{outdir}#{id}.txt", 'w')
      file.write(text)
      file.close
    end
  end
end

parse_catalog_json