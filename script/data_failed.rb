require 'logger'
require 'json'
require 'nokogiri'
require 'open-uri'

output_path = '/home/axel/Nextcloud/NewsEye/data/failed_aze'

failed_ids = File.open("/home/axel/Nextcloud/NewsEye/data/failed_aze.txt", 'r') do |f|
  f.readlines
end
nb_failed = failed_ids.size
failed_ids.each_with_index do |pageid, idx|
  puts "importing failed #{idx+1} out of #{nb_failed}"
  current_np = pageid[0..2]
  issue_id = pageid[3..pageid.index('_')-1]
  i = pageid[pageid.rindex('_')+1..-2]
  ocr_url = "https://iiif-auth.onb.ac.at/presentation/ANNO/#{current_np}#{issue_id}/resource/#{i.to_s.rjust(8, '0')}.xml"
  puts ocr_url
  begin
    if not File.file?("#{output_path}/#{current_np}#{issue_id}_page_#{i}.xml")
      ocr_file = open(ocr_url, 'r', http_basic_authentication: ['newseye','TIrl1wwNf19nmGjcnSmo'])
      IO.copy_stream(ocr_file, "#{output_path}/#{current_np}#{issue_id}_page_#{i}.xml")
    else
      puts "File already exists"
    end
  rescue OpenURI::HTTPError => e
    if "#{e}" == "400 "
      puts "failed : #{e}"
      out_file = File.new("#{output_path}/#{current_np}#{issue_id}_page_#{i}.xml", "w")
      out_file.puts("")
      out_file.close
    end
  rescue Exception => e
    puts e
  end
end