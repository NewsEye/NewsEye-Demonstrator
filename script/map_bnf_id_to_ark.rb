require 'roo-xls'
require 'json'

map = Roo::Spreadsheet.open("/home/axel/Nextcloud/NewsEye/data/bnf/EN-OCR-metadonnees/Metadonnees-OCR-EN/BnF_00028-La_Presse.xls")

sheet = map.sheet(0)

output_hash = {}

sheet.each_with_index(path: 'CHEMIN_COMPLET', ark: 'ARK_DOCNUM') do |data, idx|
  next if idx == 0
  from_id = data[:path][data[:path].rindex('\\')+1..-1]
  to_id = data[:ark]
  output_hash[from_id] = to_id
  puts from_id
  puts to_id
end

File.open("/home/axel/Nextcloud/NewsEye/data/bnf/id_mapping_presse.json","w") do |f|
  f.write(output_hash.to_json)
end