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
    end
  end

  def get_collection_title_from_id(options={})
    case options
    when String
      Newspaper.find(options).title
    when Hash
      Newspaper.find(options[:value].first).title
    else
      "placeholder newspaper title"
    end
  end

  def get_display_value_from_model(options={})
    case options
    when 'Article'
      'Content Item'
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
end
