module NamedEntitiesHelper

  def get_named_entities_for_doc doc_id
    output = {LOC: {}, PER: {}, ORG: {}, MISC: {}}
    nems = NewseyeSolrService.query({q:"doc_id_ssi:#{doc_id}", rows: 1000000})
    mapping_id_ne = Hash[NewseyeSolrService.query({q: "entity_type_ssi:*", rows: 10000}).map{ |ne| [ne['id'], {label: ne['label_ssi'], type: ne['entity_type_ssi']}] }]
    nems.select {|ne| mapping_id_ne[ne['linked_entity_ssi']][:type] == "Location"}.each do |ne|
      label = mapping_id_ne[ne['linked_entity_ssi']][:label]
      output[:LOC][label] = [] unless output[:LOC].has_key? label
      output[:LOC][label].append(ne)
    end
    nems.select {|ne| mapping_id_ne[ne['linked_entity_ssi']][:type] == "Person"}.each do |ne|
      label = mapping_id_ne[ne['linked_entity_ssi']][:label]
      output[:PER][label] = [] unless output[:PER].has_key? label
      output[:PER][label].append(ne)
    end
    nems.select {|ne| mapping_id_ne[ne['linked_entity_ssi']][:type] == "Organization"}.each do |ne|
      label = mapping_id_ne[ne['linked_entity_ssi']][:label]
      output[:ORG][label] = [] unless output[:ORG].has_key? label
      output[:ORG][label].append(ne)
    end
    nems.select {|ne| mapping_id_ne[ne['linked_entity_ssi']][:type] == "Miscellaneous"}.each do |ne|
      label = mapping_id_ne[ne['linked_entity_ssi']][:label]
      output[:MISC][label] = [] unless output[:MISC].has_key? label
      output[:MISC][label].append(ne)
    end
    output
  end

  def get_named_entities_for_article article_id
    output = {LOC: {}, PER: {}, ORG: {}, MISC: {}}
    begin
      doc_id = article_id[0...article_id.index('_article_')]
      doc_solr = NewseyeSolrService.query({q:"id:#{doc_id}"})[0]
      lang = doc_solr['language_ssi']
      doc_text = doc_solr["all_text_t#{lang}_siv"]
      article_text = NewseyeSolrService.query({q: "id:#{article_id}"})[0]["all_text_t#{lang}_siv"].gsub("\n\n","\n")
      start_index = doc_text.index(article_text)
      bounds = {start: start_index, end: start_index + article_text.size}
    rescue => e
      puts "Error during processing: #{$!}"
      puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
      return output
    end

    puts bounds
    nems = NewseyeSolrService.query({q: "doc_id_ssi:#{doc_id} AND index_start_isi:[#{bounds[:start]} TO *] AND index_end_isi:[* TO #{bounds[:end]}]", rows: 100000})
    mapping_id_ne = Hash[NewseyeSolrService.query({q: "entity_type_ssi:*", rows:10000}).map{|ne| [ne['id'], {label: ne['label_ssi'], type: ne['entity_type_ssi']}]}]

    nems.select {|ne| mapping_id_ne[ne['linked_entity_ssi']][:type] == "Location"}.each do |ne|
      label = mapping_id_ne[ne['linked_entity_ssi']][:label]
      output[:LOC][label] = [] unless output[:LOC].has_key? label
      output[:LOC][label].append(ne)
    end
    nems.select {|ne| mapping_id_ne[ne['linked_entity_ssi']][:type] == "Person"}.each do |ne|
      label = mapping_id_ne[ne['linked_entity_ssi']][:label]
      output[:PER][label] = [] unless output[:PER].has_key? label
      output[:PER][label].append(ne)
    end
    nems.select {|ne| mapping_id_ne[ne['linked_entity_ssi']][:type] == "Organization"}.each do |ne|
      label = mapping_id_ne[ne['linked_entity_ssi']][:label]
      output[:ORG][label] = [] unless output[:ORG].has_key? label
      output[:ORG][label].append(ne)
    end
    nems.select {|ne| mapping_id_ne[ne['linked_entity_ssi']][:type] == "Miscellaneous"}.each do |ne|
      label = mapping_id_ne[ne['linked_entity_ssi']][:label]
      output[:ORG][label] = [] unless output[:MISC].has_key? label
      output[:ORG][label].append(ne)
    end
    puts output
    output
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