require 'nokogiri'
require 'open-uri'

ocr_file = open('https://digi.kansalliskirjasto.fi/sanomalehti/binding/1046311/page-1.xml', 'r')
ocr = Nokogiri::XML(open(ocr_file).read)
ocr_text = ''
for line in ocr.xpath('//TextLine')
  for word in line.xpath('./String')
    ocr_text += word['CONTENT'] + ' '
  end
  ocr_text += "\n"
end
puts ocr_text