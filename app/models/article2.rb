class Article2 # < ApplicationRecord
  # serialize :canvases_parts, Array
  # after_save :index_record

  attr_accessor :id, :title, :all_text, :date_created, :language, :canvases_parts, :newspaper, :issue_id, :thumbnail_url, :bbox

  def to_solr(issue_manifest=nil)
    solr_doc = {}
    solr_doc['id'] = self.id
    solr_doc['title_ssi'] = self.title
    solr_doc["language_ssi"] = self.language
    solr_doc["all_text_t#{self.language}_siv"] = self.all_text
    solr_doc['date_created_ssi'] = self.date_created
    solr_doc['date_created_dtsi'] = DateTime.parse(self.date_created).strftime('%Y-%m-%dT%H:%M:%SZ')
    solr_doc['level'] = '0.articles'
    solr_doc['year_isi'] = solr_doc['date_created_ssi'][0..3].to_i
    solr_doc['from_issue_ssi'] = self.issue_id
    solr_doc['member_of_collection_ids_ssim'] = self.newspaper
    solr_doc['canvases_parts_ssm'] = self.canvases_parts
    solr_doc['thumbnail_url_ss'] =  self.get_thumbnail_url(issue_manifest) unless issue_manifest.nil?
    solr_doc['has_model_ssim'] = 'Article'
    solr_doc['discover_access_group_ssim'] = ['admin', 'researcher', 'registered']
    if self.language == "fi" or self.language == "se"
      solr_doc['read_access_group_ssim'] = ['admin', 'researcher']
    else
      solr_doc['read_access_group_ssim'] = ['admin', 'researcher', 'registered']
    end
    # solr_doc['bounds'] = "TODO"
    solr_doc
  end

  def get_thumbnail_url manifest
    canvas_url = self.canvases_parts[0]
    coords = self.canvases_parts.map { |c| c[c.rindex('#xywh=')+6..-1].split(',').map(&:to_i) }
    min_x = coords.map{ |coord| coord[0] }.min
    max_x = coords.map{ |coord| coord[0] + coord[2] }.max
    min_y = coords.map{ |coord| coord[1] }.min
    max_y = coords.map{ |coord| coord[1] + coord[3] }.max
    pagenum = canvas_url[canvas_url.rindex('_')+1...canvas_url.rindex('#')].to_i
    "#{manifest['sequences'][0]['canvases'][pagenum-1]['images'][0]['resource']['service']['@id']}/#{min_x},#{min_y},#{max_x-min_x},#{max_y-min_y}/!400,200/0/default.jpg"
  end

  def self.from_solr id
    attrs = NewseyeSolrService.get_by_id id
    a = Article2.new
    a.id = attrs['id']
    a.title = attrs['title_ssi']
    a.language = attrs['language_ssi']
    a.all_text = attrs["all_text_t#{a.language}_siv"]
    a.date_created = attrs['date_created_ssi']
    a.issue_id = attrs['from_issue_ssi']
    a.newspaper = attrs['member_of_collection_ids_ssim'].first
    a.canvases_parts = attrs['canvases_parts_ssm']
    a.bbox = a.get_location
    a
  end

  def self.from_solr_doc solr_doc
    a = Article2.new
    a.id = solr_doc['id']
    a.title = solr_doc['title_ssi']
    a.language = solr_doc['language_ssi']
    a.all_text = solr_doc["all_text_t#{a.language}_siv"]
    a.date_created = solr_doc['date_created_ssi']
    a.issue_id = solr_doc['from_issue_ssi']
    a.newspaper = solr_doc['member_of_collection_ids_ssim'].first
    a.canvases_parts = solr_doc['canvases_parts_ssm']
    a.bbox = a.get_location
    a
  end

  def draw ### !!!!! si sur une seule page
    out = {}
    coords = self.canvases_parts.map { |c| c[c.rindex('#xywh=')+6..-1].split(',').map(&:to_i) }
    min_x = coords.map{ |coord| coord[0] }.min
    max_x = coords.map{ |coord| coord[0] + coord[2] }.max
    min_y = coords.map{ |coord| coord[1] }.min
    max_y = coords.map{ |coord| coord[1] + coord[3] }.max
    canvas_coords = [min_x, max_x, min_y, max_y]
    canvas_size = [canvas_coords[1]-canvas_coords[0], canvas_coords[3]-canvas_coords[2]]
    new_coords = coords.map{ |coord| [coord[0]-min_x, coord[1]-min_y, coord[2], coord[3]] }
    out[:canvas_size] = canvas_size
    out[:parts] = []
    self.canvases_parts.map do |c|
      coord = c[c.rindex('#xywh=')+6..-1].split(',').map(&:to_i)
      coord = [coord[0]-min_x, coord[1]-min_y, coord[2], coord[3]]
      manifest = ApplicationController.helpers.get_manifest self.issue_id
      url = ApplicationController.helpers.get_iiif_images_from_canvas_path manifest, c
      out[:parts] << [url, coord]
    end
    out
  end

  def get_page
    cv = self.canvases_parts[0]
    page = cv[cv.index("/page_")+6...cv.index("#xywh")]
    page
  end

  def get_location
    coords = self.canvases_parts.map { |c| c[c.rindex('#xywh=')+6..-1].split(',').map(&:to_i) }
    min_x = coords.map{ |coord| coord[0] }.min
    max_x = coords.map{ |coord| coord[0] + coord[2] }.max
    min_y = coords.map{ |coord| coord[1] }.min
    max_y = coords.map{ |coord| coord[1] + coord[3] }.max
    canvas_coords = [min_x, max_x, min_y, max_y]
    canvas_size = [canvas_coords[1]-canvas_coords[0], canvas_coords[3]-canvas_coords[2]]
    [min_x,min_y,canvas_size[0],canvas_size[1]]
  end
end
