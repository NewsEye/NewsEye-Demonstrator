# -*- encoding : utf-8 -*-

class AnnotationsController < ApplicationController

  def search
    puts params[:layer]
    uri, sep, layer = params[:uri].rpartition('_')
    if not %w(word line block).include? layer
      render json: []
    else
      layer_uri = uri.rpartition('/')[0].rpartition('/')[0] + '/layer/ocr_' + layer + '_level'
      url = "http://localhost:8888/annotation/search?uri=#{uri}&layer=#{layer_uri}&media=#{params[:media]}&limit=#{params[:limit]}"
      puts url
      response = HTTParty.get(url)
      render json: response.body
    end
  end

  def add_annotation
    render json: {title: Rails.configuration.newseye_services['annotations_endpoint']}
  end

end
