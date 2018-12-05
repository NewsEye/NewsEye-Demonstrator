require 'nokogiri'
require 'pp'
require 'charlock_holmes'
require 'json'

encoding = CharlockHolmes::EncodingDetector.detect(File.read("/home/axel/Nextcloud/NewsEye/newseye_samvera/db/seeds_data/12148-bpt6k276749p_page_1.xml"))[:ruby_encoding]
puts encoding
doc = File.open("/home/axel/Nextcloud/NewsEye/newseye_samvera/db/seeds_data/12148-bpt6k276749p_page_1.xml") do |f|
  Nokogiri::XML(f, nil, encoding)
end
doc.remove_namespaces!
annotation_list = {}
annotation_list['@context'] = 'http://iiif.io/api/presentation/2/context.json'
annotation_list['@id'] = 'http://localhost:3000/iiif/Le_Figaro_12148-bpt6k276749p/list/page_1_ocr'
annotation_list['@type'] = 'sc:AnnotationList'
annotation_list['resources'] = []

doc.xpath('//TextLine').each do |line|
  annot = {}
  annot['@type'] = 'oa:Annotation'
  annot['motivation'] = 'sc:painting'
  annot['resource'] = {}
  annot['resource']['@type'] = 'cnt:ContentAsText'
  annot['resource']['format'] = 'text/plain'
  text = []
  confidence = 0
  line.children.each do |str|
    if str.name == 'String'
      text << str['CONTENT'].force_encoding(encoding).encode('UTF-8')
      confidence += str['WC'].to_f
    end
  end
  annot['resource']['chars'] = text.join(' ')
  annot['metadata'] = {}
  annot['metadata']['word_confidence'] = text.size == 0 ? 0 : confidence / text.size
  annot['on'] = "http://localhost:3000/iiif/Le_Figaro_12148-bpt6k276749p/canvas/page_1#xywh=#{line['HPOS']},#{line['VPOS']},#{line['WIDTH']},#{line['HEIGHT']}"
  annotation_list['resources'] << annot
end

annotation_list['within'] = {}
annotation_list['within']['@id'] = '<host>/iiif/Le_Figaro_12148-bpt6k276749p/layer/ocr'
annotation_list['within']['@type'] = 'sc:Layer'
annotation_list['within']['label'] = 'OCR Layer'

puts annotation_list.to_json