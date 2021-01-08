module NamedEntitiesHelper

  def get_named_entities_for_doc doc_id
    output = {LOC: {}, PER: {}, ORG: {}, HumanProd: {}}
    if doc_id.index('_article_').nil?
      nems = NewseyeSolrService.query({q:"issue_id_ssi:#{doc_id}", rows: 1000000})
    else
      nems = NewseyeSolrService.query({q:"article_id_ssi:#{doc_id}", rows: 1000000})
    end
    nems.select {|ne_solr| ne_solr['type_ssi'] == "LOC"}.each do |ne_solr|
      output[:LOC][ne_solr['linked_entity_ssi']] = [] unless output[:LOC].has_key? ne_solr['linked_entity_ssi']
      output[:LOC][ne_solr['linked_entity_ssi']].append(ne_solr)
    end
    nems.select {|ne_solr| ne_solr['type_ssi'].start_with? "PER"}.each do |ne_solr|
        output[:PER][ne_solr['linked_entity_ssi']] = [] unless output[:PER].has_key? ne_solr['linked_entity_ssi']
        output[:PER][ne_solr['linked_entity_ssi']].append(ne_solr)
    end
    nems.select {|ne_solr| ne_solr['type_ssi'].start_with? "ORG"}.each do |ne_solr|
        output[:ORG][ne_solr['linked_entity_ssi']] = [] unless output[:ORG].has_key? ne_solr['linked_entity_ssi']
        output[:ORG][ne_solr['linked_entity_ssi']].append(ne_solr)
    end
    nems.select {|ne_solr| ne_solr['type_ssi'] == "HumanProd"}.each do |ne_solr|
      output[:HumanProd][ne_solr['linked_entity_ssi']] = [] unless output[:HumanProd].has_key? ne_solr['linked_entity_ssi']
      output[:HumanProd][ne_solr['linked_entity_ssi']].append(ne_solr)
    end
    output
  end

  def get_kb_urls entities
      ids = entities.select{ |label| label != "" }
      return {} if ids.empty?
      NewseyeSolrService.query({q: "*:*", fq: "id:(#{ids.join(' ')})", fl: "id,kb_url_ssi", rows: 99999}).map do |res|
          [res['id'], res['kb_url_ssi']]
      end.to_h
  end

  def get_linked_entities entities
      priority_language = [I18n.locale, 'en', 'de', 'fr', 'fi', 'sv']
      ids = entities.select{ |label| label != "" }
      return {} if ids.empty?
      out = {}
      NewseyeSolrService.query({q: "*:*", fq: "id:(#{ids.join(' ')})", fl: "*", rows: 99999}).map do |res|
          priority_language.each do |lang|
              unless res["label_#{lang}_ssi"].nil?
                  out[res['id']] = {kb_url: res['kb_url_ssi'], label: res["label_#{lang}_ssi"]}
                  break
              end
          end
      end
      out
  end

  def get_entity_label(options={})
    priority_language = [I18n.locale, 'en', 'de', 'fr', 'fi', 'sv']
    if options.class == Array
        out = {}
        docs = NewseyeSolrService.query({q: "*:*", fq: "id:(#{options.join(' ')})", fl: "*", rows: 99999})
        docs.map do |doc|
            priority_language.each do |lang|
                if doc["label_#{lang}_ssi"].nil?
                    out[doc['id']] = doc["label_#{lang}_ssi"]
                    break
                end
            end
        end
        return out
    else
        doc = NewseyeSolrService.get_by_id options
        unless doc.nil?
            priority_language.each do |lang|
                return doc["label_#{lang}_ssi"] unless doc["label_#{lang}_ssi"].nil?
            end
        end
    end
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