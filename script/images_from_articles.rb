# create an image of an article to be annotated.
# Add bounding boxes of words
# Make a chart with available data, articles separated, named entities. Just put every data available in a doc to summarize
# t1 = Time.now
# NewseyeSolrService.query({q: "id:la_fronde_12148-bpt6k6706398h_1_word*", rows: 9999999})
# t2 = Time.now
# NewseyeSolrService.query({q: "id:la_fronde_12148-bpt6k6706398h_page_1", fl: "id, [child parentFilter=level:1.* childFilter=level:4.* limit=9999999]"})
# t3 = Time.now
# puts "word*: #{(t2-t1).seconds}s"
# puts "child: #{(t3-t2).seconds}s"

require 'open-uri'
require 'mini_magick'

issueid = 'le_gaulois_12148-bpt6k519386p'
articlenums = Array(1..60)

ratio = 2.0/3
issue = Issue2.from_solr issueid, with_pages: true, with_articles: true, with_word_annots: true

articlenums.each do |articlenum|
  images = {}
  bboxes = {}
  issue.articles[articlenum].canvases_parts.map { |c| c[c.index('/canvas/page_')+13...c.index('#xywh=')] }.uniq.map(&:to_i).each do |pagenum|
    MiniMagick::Tool::Convert.new do |i|
      i.size "#{(issue.pages[pagenum].width * ratio).to_i}x#{(issue.pages[pagenum].height * ratio).to_i}"
      i.xc "white"
      i << "#{issueid}_article_#{articlenum}_page_#{pagenum}.png"
    end
    images[pagenum] = MiniMagick::Image.open("#{issueid}_article_#{articlenum}_page_#{pagenum}.png")
    bboxes[pagenum] = []
  end


  ind = 0
  issue.articles[articlenum].canvases_parts.each do |canvas|
    ind += 1
    page = canvas[canvas.index('/canvas/page_')+13...canvas.index('#xywh=')].to_i
    x, y, w, h = canvas[canvas.index("#xywh=")+6..-1].split(',').map!(&:to_i)
    image_url = ApplicationController.helpers.get_iiif_images_from_canvas_path(issue.manifest("http://localhost:3000"), canvas)
    # image_url[-4..-1] = ".png"
    puts "#{ind} out of #{issue.articles[articlenum].canvases_parts.size}.    #{image_url}"
    unless w == 0 && h == 0
      # image_file = open(image_url, "User-Agent" => "Mozilla/5.0 (...) Firefox/3.0.6").read # , "Authorization" => "JWT eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE1NjgyMTY4ODR9.YIpk7pT2zVNaxVNDtk4BO-TqNfwgcsXle3wyQXF_5rU").read
      image_part = MiniMagick::Image.open(image_url)
      image_part.resize "#{ratio*100}%"
      puts "replacing pixels..."
      images[page] = images[page].composite(image_part) do |c|
        # c.gravity "center"
        c.geometry "+#{x * ratio}+#{y * ratio}"
        c.compose "over"
      end
      bboxes[page].push(*get_annots_bbox(issue.word_annots, x, y, w, h, page, ratio))
      puts "#{bboxes[page].size} annotations found"
    end
  end
  images.keys.each do |imkey|
    puts "drawing bboxes..."
    images[imkey].combine_options do |b|
      b.fill "none"
      b.stroke "SkyBlue1"
      b.strokewidth 1
      b.draw bboxes[imkey].map{ |bbox| "rectangle #{bbox[0]},#{bbox[1]},#{bbox[0] + bbox[2]},#{bbox[1] + bbox[3]}" }.join(' ')
    end
    puts "saving..."
    images[imkey].write("#{issueid}_article_#{articlenum}_page_#{imkey}.png")
  end
end

BEGIN{
  def get_annots_bbox(word_annots, x, y, w, h, pagenum, ratio)
    out = word_annots.map do |wa|
      next if wa["on"][wa["on"].index("/canvas/page_")+13...wa["on"].index("#xywh=")].to_i != pagenum
      x2, y2, w2, h2 = wa["on"][wa["on"].index('#xywh=')+6..-1].split(',').map(&:to_i)
      if x2 >= x && y2 >= y && x2 + w2 <= x + w && y2 + h2 <= y + h
        # puts "#{x2}, #{y2}, #{w2}, #{h2}"
        [(x2*ratio).to_i, (y2*ratio).to_i, (w2*ratio).to_i, (h2*ratio).to_i]
      end
    end
    out.reject(&:nil?)
  end
}