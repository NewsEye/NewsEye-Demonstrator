# -*- encoding : utf-8 -*-

class IiifController < ApplicationController
  def manifest
    render json: IIIFManifest::ManifestFactory.new(Issue.find(params[:id])).to_h
  end

  def annotation_list
    render json: {name: params[:name], id: params[:id]}
  end
end