require 'nokogiri'
require 'charlock_holmes'

issue_dir = "/home/axel/Nextcloud/NewsEye/data/bnf/19210910_1/"
mets_file = "#{issue_dir}19210910_1-METS.xml"
alto_docs = {}
Dir.glob("#{issue_dir}ALTO/*.xml").each do |alto_file|
  num_page = alto_file[-8..-5].to_i
  encoding = CharlockHolmes::EncodingDetector.detect(File.read(alto_file))[:ruby_encoding]
  doc = File.open(alto_file) do |f|
    Nokogiri::XML(f, nil, encoding)
  end
  doc.remove_namespaces!
  alto_docs[num_page] = doc
end
t = get_text_from_id(alto_docs[1], "P1_TB00001")
puts t
encoding = CharlockHolmes::EncodingDetector.detect(File.read(mets_file))[:ruby_encoding]
doc = File.open(mets_file) do |f|
  Nokogiri::XML(f, nil, encoding)
end
doc.remove_namespaces!

puts "title section : "
s = doc.xpath("/descendant::structMap[@TYPE='LOGICAL']/descendant::div[@TYPE='ISSUE']/div[@TYPE='TITLE_SECTION']//@BEGIN")
s = s.map(&:text)
hpos, vpos, width, height = get_bbox(alto_docs, s)
puts "hpos: #{hpos}, vpos: #{vpos}, width: #{width}, height: #{height}"

puts "articles"
doc.xpath("/descendant::structMap[@TYPE='LOGICAL']/descendant::div[@TYPE='ISSUE']/div[@TYPE='CONTENT']//div[@TYPE='ARTICLE']").each do |article|
  puts article.xpath("./@ID")
  tbs = {heading: [], body: []}
  tbs[:heading] << article.xpath(".//div[@TYPE='HEADING']//@BEGIN").map(&:text)
  tbs[:body] << article.xpath(".//div[@TYPE='BODY']//@BEGIN").map(&:text)
  heading_bboxes = get_bbox(alto_docs, tbs[:heading])
  body_bboxes = get_bbox(alto_docs, tbs[:body])
  bboxes.each do |bbox|
    hpos, vpos, width, height = bbox
    puts "hpos: #{hpos}, vpos: #{vpos}, width: #{width}, height: #{height}"
  end
end

BEGIN{
  def get_text_from_id(alto_doc, textblock_id)
    alto_doc.xpath("//TextBlock[@ID='#{textblock_id}']//@CONTENT").to_s.gsub("\n", " ")
  end

  def get_text(alto_doc, textblocks)
    text = ""
    textblocks.each do |tb|
      text = "#{text} #{get_text_from_id(alto_doc, tb)}"
    end
    text
  end

  def get_bbox(alto_doc, textblocks)
    bboxes = []
    min_hpos = 100000
    min_vpos = 100000
    max_hpos = 0
    max_vpos = 0
    puts "#{textblocks.size} textblocks"
    pages = textblocks.map{ |tb| tb[1...tb.index('_')].to_i }.uniq!
    puts "pages : #{pages.join(' ')}"
    pages.each do |page|
      puts "page #{page} :"
      textblocks.select{ |tb| tb.index("P#{page}_") }.each do |tb|
        hpos = alto_doc[page].xpath("//TextBlock[@ID='#{tb}']/@HPOS").to_s.to_i
        vpos = alto_doc[page].xpath("//TextBlock[@ID='#{tb}']/@VPOS").to_s.to_i
        width = alto_doc[page].xpath("//TextBlock[@ID='#{tb}']/@WIDTH").to_s.to_i
        height = alto_doc[page].xpath("//TextBlock[@ID='#{tb}']/@HEIGHT").to_s.to_i
        puts "  #{tb}"
        hpos2 = hpos + width
        vpos2 = vpos + height
        min_hpos = hpos < min_hpos ? hpos : min_hpos
        min_vpos = vpos < min_vpos ? vpos : min_vpos
        max_hpos = hpos2 > max_hpos ? hpos2 : max_hpos
        max_vpos = vpos2 > max_vpos ? vpos2 : max_vpos
      end
      bboxes << [min_hpos, min_vpos, max_hpos-min_hpos, max_vpos-min_vpos]
    end
    bboxes
  end
}