require 'rsolr'
require 'json'
require 'nokogiri'

alto = 'ALTO'
# newspaper_dir = "/home/axel/Nextcloud/NewsEye/data/bnf/le matin"
# mapping = JSON.parse(File.open("/home/axel/Nextcloud/devops/id_mapping_matin.json").read)
# metadata_dir = "/home/axel/Nextcloud/NewsEye/data/import_le_matin"

newspaper_dir = "/home/axel/Nextcloud/NewsEye/data/bnf/le gaulois"
mapping = JSON.parse(File.open("/home/axel/Nextcloud/devops/id_mapping_gaulois.json").read)
metadata_dir = "/home/axel/Nextcloud/NewsEye/data/import_le_gaulois"

# alto = 'alto'
# newspaper_dir = "/home/axel/Nextcloud/NewsEye/data/bnf/la presse"
# mapping = JSON.parse(File.open("/home/axel/Nextcloud/devops/id_mapping_presse.json").read)
# metadata_dir = "/home/axel/Nextcloud/NewsEye/data/bnf/la presse/metadata"

out_dir = '/home/axel/Nextcloud/devops/data'

sample = 100
nb_processed = 0

issues_dir = Dir.entries(newspaper_dir).select {|entry| File.directory? File.join(newspaper_dir, entry) and !(entry =='.' || entry == '..') }
issues_dir.each do |issue_dir|
  begin
    puts issue_dir
    if alto == 'alto'  # if la presse
      issue_bad_id = issue_dir[10..-1]
    else
      issue_bad_id = issue_dir[0...issue_dir.rindex('_')]
    end
    puts issue_bad_id
    ark = mapping[issue_bad_id]
    puts ark
    issue_id = ark[5..-1].gsub('/', '-')

    json_metadata_file = "#{metadata_dir}/#{issue_id}.json"

    FileUtils.cp(json_metadata_file, "#{out_dir}/#{issue_id}.json")

    pages_xml = Dir.entries("#{newspaper_dir}/#{issue_dir}/#{alto}").select {|entry| !(entry =='.' || entry == '..') }
    # pages_xml.map! {|page| page[page.rindex('-')+1..-1] }
    pages_xml.sort!
    pages_xml.each_with_index do |page, ind|
      old_page = "#{newspaper_dir}/#{issue_dir}/#{alto}/#{page}"
      new_page = "#{out_dir}/#{issue_id}_page_#{ind+1}.xml"
      puts old_page
      puts new_page
      FileUtils.cp(old_page, new_page)
    end
    nb_processed = nb_processed + 1
    break if nb_processed == sample
  rescue
    next
  end
end