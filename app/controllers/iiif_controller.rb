# -*- encoding : utf-8 -*-

class IiifController < ApplicationController
  def manifest(with_articles: false)
    # man = JSON.parse(Issue.find(params[:id]).manifest(request.protocol+request.host_with_port).to_json)
    man = JSON.parse(Issue2.from_solr(params[:id], with_pages: true, with_articles: with_articles).manifest(request.protocol+request.host_with_port).to_json)
    # man['service'] = {}
    # man['service']['@context'] = "http://iiif.io/api/search/1/context.json"
    # man['service']['@id'] = "http://localhost:8888/search-api/#{params[:id]}/search"
    # man['service']['@profile'] = "http://iiif.io/api/search/1/search"
    render json: man
  end

  # def manifest_with_annotations
  #   render json: JSON.parse(Issue2.from_solr(params[:id]).manifest(request.protocol+request.host_with_port, with_annotations: true).to_json)
  # end

  def annotation_list
    if params[:name].include? "page_" and params[:name].include? "_ocr_"
      pfs_id = params[:id] + '_page_' + params[:name].split('_')[1]
      case params[:name].split('_')[2..-1].join('_')
      when 'ocr_word_level'
        render json: PageFileSet2.from_solr(pfs_id).generate_word_annotation_list
      when 'ocr_line_level'
        render json: JSON.parse(PageFileSet2.from_solr(pfs_id).ocr_line_level_annotation_list.content)
      when 'ocr_block_level'
        render json: JSON.parse(PageFileSet2.from_solr(pfs_id).ocr_block_level_annotation_list.content)
      end
    elsif params[:name].include? "article_"
      article_id = "#{params[:id]}_article_#{params[:name].split('_')[1]}"
      render json: Article2.from_solr(article_id).annotation_list
    end
  end

  def layer
    l = {}
    l['@context'] = 'http://iiif.io/api/presentation/2/context.json'
    l['@id'] = "#{request.protocol+request.host_with_port}/iiif/#{params[:id]}/layer/#{params[:name]}"
    l['@type'] = 'sc:Layer'
    l['label'] = params[:id] + ' ' + params[:name]
    l['otherContent'] = []
    if params[:name].include? "ocr_"
      nb_page = Issue2.from_solr(params[:id]).nb_pages
      for i in 1..nb_page
        l['otherContent'] << "#{request.protocol+request.host_with_port}/iiif/#{params[:id]}/list/page_#{i}_#{params[:name]}"
      end
    elsif params[:name].include? "articles_"
      Issue2.from_solr(params[:id]).articles.each do |article|
        l['otherContent'] << "#{request.protocol+request.host_with_port}/iiif/#{params[:id]}/list/article_#{article.id[article.id.rindex('_')+1..-1]}_#{params[:name][params[:name].index('_')+1..-1]}"
      end
    end
    render json: l
  end

  def alto
    path = NewseyeSolrService.query({q: "id:#{params['id']}", fl: "ocr_path_ss", rows: 1})[0]
    if path['ocr_path_ss']
      send_file path['ocr_path_ss'],
                filename: "#{params['id']}.xml",
                type: "application/xml"
    end
  end

  def get_image_resource_proxy
    # https://iiif-auth.onb.ac.at/images/ANNO/nfp19160707/00000001
    # http://localhost:3000/iiif/Neue_freie_Presse_nfp19160707_page_1
    redirect_to controller: 'riiif/images', action: 'show'
  end
end