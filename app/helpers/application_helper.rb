module ApplicationHelper

  def convert_date_to_locale(options={})
    case options
    when String
      I18n.localize Date.parse(options)
    when Hash
      I18n.localize Date.parse(options[:value].first)
    else
      "placeholder date"
    end
  end

  def convert_language_to_locale(options={})
    case options
    when 'fr'
      t('newseye.language.fr')
    when 'fi'
      t('newseye.language.fi')
    when 'en'
      t('newseye.language.en')
    when 'de'
      t('newseye.language.de')
    when 'se'
      t('newseye.language.se')
    end
  end

  def get_collection_title_from_id(options={})
    case options
    when String
      npid = options
    when Hash
      npid = options[:value].first
    else
      npid = nil
    end
    if npid
      # ActiveFedora::SolrService.instance.conn.get('select', params: {q: "id:#{npid}"})['response']['docs'][0]['title_ssi']
      case npid
      when 'l_oeuvre'
        "L'Œuvre"
      when 'paivalehti'
        "Paivalehti"
      when 'arbeiter_zeitung'
        "Arbeiter Zeitung"
      when 'uusi_suometar'
        "Uusi Suometar"
      when 'abo_underrattelser'
        "Åbo Underrättelser"
      end
    else
      "placeholder newspaper title"
    end
  end

  def get_display_value_from_model(options={})
    case options
    when 'Article'
      'Article'
    when 'Issue'
      'Issue'
    end
  end

  def get_iiif_images_from_canvas_path(manifest, canvas_url)
    pagenum = canvas_url[canvas_url.rindex('_')+1...canvas_url.rindex('#')].to_i
    x, y , w, h = canvas_url[canvas_url.rindex('xywh=')+5..-1].split(',').map(&:to_i)
    "#{manifest['sequences'][0]['canvases'][pagenum-1]['images'][0]['resource']['service']['@id']}/#{x},#{y},#{w},#{h}/full/0/default.jpg"
  end

  def get_manifest(issue_id)
    man = JSON.parse(Issue.find(issue_id).manifest(Rails.configuration.newseye_services['host']).to_json)
    man['service'] = {}
    man['service']['@context'] = "http://iiif.io/api/search/1/context.json"
    man['service']['@id'] = "http://localhost:8888/search-api/#{params[:id]}/search"
    man['service']['@profile'] = "http://iiif.io/api/search/1/search"
    man
  end

  def get_bbox_from_annotations(annots)
    minx = 99999999
    maxx = 0
    miny = 99999999
    maxy = 0
    annots.each do |annot|
      annot_bbox = annot.match /.*#xywh=(?<x>\d+),(?<y>\d+),(?<w>\d+),(?<h>\d+)/
      minx = annot_bbox[:x].to_i if annot_bbox[:x].to_i < minx
      miny = annot_bbox[:y].to_i if annot_bbox[:y].to_i < miny
      maxx = annot_bbox[:x].to_i + annot_bbox[:w].to_i if annot_bbox[:x].to_i + annot_bbox[:w].to_i > maxx
      maxy = annot_bbox[:y].to_i + annot_bbox[:h].to_i if annot_bbox[:y].to_i + annot_bbox[:h].to_i > maxy
    end
    "#{minx},#{miny},#{maxx-minx},#{maxy-miny}"
  end
end
