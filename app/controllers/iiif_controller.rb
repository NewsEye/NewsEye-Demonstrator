# -*- encoding : utf-8 -*-

class IiifController < ApplicationController
  def manifest
    render json: IIIFManifest::ManifestFactory.new(Issue.find(params[:id])).to_h
  end
end