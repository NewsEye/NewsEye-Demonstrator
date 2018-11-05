# -*- encoding : utf-8 -*-

class IiifController < ApplicationController
  def manifest
    render json: JSON.parse(Issue.find(params[:id]).manifest(request.protocol+request.host_with_port).to_json)
  end

  def annotation_list
    render json: {
        "@context": "http://iiif.io/api/presentation/2/context.json",
        "@id": "http://localhost:3000/iiif/"+params[:id]+"/list/"+params[:name],
        "@type": "sc:AnnotationList",

        "resources": [
            {
                "@type": "oa:Annotation",
                "motivation": "sc:painting",
                "resource":{
                    "@type": "cnt:ContentAsText",
                    "format": "text/plain",
                    "chars": "this is a test"
                },
                "on": "http://localhost:3000/iiif/"+params[:id]+"/manifest.json/canvas/Le_Figaro_12148-bpt6k276749p_page_1#xywh=100,100,1000,1000"
            }
        ]
      }
  end

  def layer
    render json: {
          "@context": "http://iiif.io/api/presentation/2/context.json",
          "@id": "http://example.org/iiif/book1/layer/transcription",
          "@type": "sc:Layer",
          "label": "Diplomatic Transcription",
          "otherContent": [
              "http://example.org/iiif/book1/list/l1"
          ]
        }
  end
end