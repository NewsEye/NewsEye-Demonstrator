module NamedEntitiesHelper
  def get_named_entity_mentions_for_doc(doc_id)
    NamedEntityMention.where(doc_id: doc_id)
  end

  def get_named_entities_for_doc doc_id
    output = {LOC: {}, PER: {}, ORG: {}}
    nems = NamedEntityMention.joins(:named_entity).select("named_entities.ne_type, named_entities.label, named_entity_mentions.*").where('named_entity_mentions.doc_id': doc_id)
    nems.select {|ne| ne.ne_type == "LOC"}.each do |ne|
      output[:LOC][ne.label] = [] unless output[:LOC].has_key? ne.label
      output[:LOC][ne.label].append(ne)
    end
    nems.select {|ne| ne.ne_type == "PER"}.each do |ne|
      output[:PER][ne.label] = [] unless output[:PER].has_key? ne.label
      output[:PER][ne.label].append(ne)
    end
    nems.select {|ne| ne.ne_type == "ORG"}.each do |ne|
      output[:ORG][ne.label] = [] unless output[:ORG].has_key? ne.label
      output[:ORG][ne.label].append(ne)
    end
    output
  end
end