require 'net/http'
require 'uri'
require 'json'

# def get_auth_token
#   uri = URI.parse("http://localhost:3000/authenticate")
#   header = {'Content-Type': 'application/json'}
#   user = {
#       email: 'r1@univ.com',
#       password: 'password'
#   }
# # Create the HTTP objects
#   http = Net::HTTP.new(uri.host, uri.port)
#   request = Net::HTTP::Post.new(uri.request_uri, header)
#   request.body = user.to_json
# # Send the request
#   response = http.request(request)
#   JSON.parse(response.body)['auth_token']
# end
#
# def query
#   header = {'Content-Type': 'application/json', 'Authorization': get_auth_token}
#   url = URI.parse "https://platform.newseye.eu/fr/catalog.json?f[member_of_collection_ids_ssim][]=uusisuometar&rows=100&page=1"
#   req = Net::HTTP::Get.new(url.to_s)
#   http = Net::HTTP.new(url.host, url.port)
#   http.use_ssl = true
#   res = http.request(req)
#   puts res.body
# end

def parse_catalog_json
  outdir = "/home/axel/Téléchargements/finnish_texts2/"
  (0..17).each do |i|
    file = "/home/axel/Téléchargements/catalog(#{i}).json"
    data = JSON.parse(File.read(file))
    data['response']['docs'].each do |doc|
      id = doc['id']
      text = doc['all_text_tfi_siv']
      puts id
      file = File.open("#{outdir}#{id}.txt", 'w')
      file.write(text)
      file.close
    end
  end
end

parse_catalog_json