# -*- encoding : utf-8 -*-

class IiifController < ApplicationController
  def manifest
    render json: JSON.parse(Issue.find(params[:id]).manifest(request.protocol+request.host_with_port).to_json)
  end

  def manifest_with_annotations
    render json: JSON.parse(Issue.find(params[:id]).manifest(request.protocol+request.host_with_port, with_annotations=true).to_json)
  end

  def annotation_list
    pfs_id = params[:id] + '_page_' + params[:name].split('_')[1]
    render json: JSON.parse(PageFileSet.find(pfs_id).annotation_list(request.protocol+request.host_with_port, params[:name].split('_')[2..-1].join('_')))
  end

  def layer
    l = {}
    l['@context'] = 'http://iiif.io/api/presentation/2/context.json'
    l['@id'] = "#{request.protocol+request.host_with_port}/iiif/#{params[:id]}/layer/#{params[:name]}"
    l['@type'] = 'sc:Layer'
    l['label'] = params[:id] + ' ' + params[:name]
    l['otherContent'] = []
    nb_page = Issue.find(params[:id]).nb_pages
    for i in 1..nb_page
      l['otherContent'] << "#{request.protocol+request.host_with_port}/iiif/#{params[:id]}/list/page_#{i}_#{params[:name]}"
    end

    render json: l
  end
end