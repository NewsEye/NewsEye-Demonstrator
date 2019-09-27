  require 'json'
  require 'nokogiri'
  require 'open-uri'

  dir = "/home/axel"

  Dir["#{dir}/*.json"].each do |filename|
    if filename == "/home/axel/json_to_fix.json"
      data = JSON.parse(File.open(filename).read)
      binding_id = data["original_uri"].split('/')[-1]
      metadata_doc = Nokogiri::XML(open("https://digi.kansalliskirjasto.fi/interfaces/OAI-PMH?verb=GetRecord&metadataPrefix=oai_dc&identifier=oai:digi.kansalliskirjasto.fi:#{binding_id}").read)
      metadata_doc.remove_namespaces!
      data['title'] = metadata_doc.xpath('//metadata//title').text
      data['date_created'] = metadata_doc.xpath('//metadata//date').text
      data['language'] = metadata_doc.xpath('//metadata//language').text
      File.open(filename, 'w') do |f|
        f.write(JSON.pretty_generate(data))
      end

    end
  end