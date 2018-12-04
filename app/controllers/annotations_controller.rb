# -*- encoding : utf-8 -*-

class AnnotationsController < ApplicationController

  def search
    uri, sep, layer = params[:uri].rpartition('_')
    puts uri
    if not %w(word line block).include? layer
      puts layer
      render json: []
    else
      doc_id = uri[uri.index('iiif/')+5...uri.index('/canvas/')]
      page_num = uri.rpartition('_')[2]
      annotation_list = {}
      annotation_list['@context'] = 'http://iiif.io/api/presentation/2/context.json'
      annotation_list['@id'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/list/page_#{page_num}_ocr_#{layer}_level"
      annotation_list['@type'] = 'sc:AnnotationList'
      annotation_list['resources'] = []
      annotation_list['within'] = {}
      annotation_list['within']['@id'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{doc_id}/layer/ocr_#{layer}_level"
      annotation_list['within']['@type'] = 'sc:Layer'
      annotation_list['within']['label'] = 'OCR Layer'
      level = case layer
              when 'word'
                '4.pages.blocks.lines.words'
              when 'line'
                '3.pages.blocks.lines'
              when 'block'
                '2.pages.blocks'
              else
                '*'
              end
      flarg = "*, [child parentFilter=level:1.* childFilter=level:#{level} limit=1000000]"
      # TODO check that solr doesnt contains multiple docs with same id...
      puts "###"
      puts "id:#{doc_id}_page_#{page_num}"
      puts flarg
      puts ActiveFedora::SolrService.query("id:#{doc_id}_page_#{page_num}", {fl: flarg}).size
      puts "###"
      ActiveFedora::SolrService.query("id:#{doc_id}_page_#{page_num}", {fl: flarg}).first['_childDocuments_'].each do |annot|
        block_annot = {}
        block_annot['@type'] = 'oa:Annotation'
        block_annot['motivation'] = 'sc:painting'
        block_annot['resource'] = {}
        block_annot['resource']['@type'] = 'cnt:ContentAsText'
        block_annot['resource']['format'] = 'text/plain'
        block_annot['resource']['chars'] = annot['text']
        block_annot['metadata'] = {}
        block_annot['metadata'] = {}
        # block_annot['metadata']['word_confidence'] = block_text.size == 0 ? 0 : block_confidence / block_text.size
        block_annot['on'] = "#{uri+annot['selector']}"
        annotation_list['resources'] << block_annot
      end
      render json: annotation_list['resources'].to_json
    end
  #   puts params[:layer]
  #   uri, sep, layer = params[:uri].rpartition('_')
  #   if not %w(word line block).include? layer
  #     render json: []
  #   else
  #     layer_uri = uri.rpartition('/')[0].rpartition('/')[0] + '/layer/ocr_' + layer + '_level'
  #     url = "http://localhost:8888/annotation/search?uri=#{uri}&layer=#{layer_uri}&media=#{params[:media]}&limit=#{params[:limit]}"
  #     puts url
  #     response = HTTParty.get(url)
  #     render json: response.body
  #   end
  end

end
