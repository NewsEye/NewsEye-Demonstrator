class NamedEntity #< ApplicationRecord
  # has_many :named_entity_mentions

  #after_save :index_record

  attr_accessor :id, :ne_type, :labels, :kb_url

  def to_solr
    entity = {
        id: "#{self.id}",
        entity_type_ssi: self.ne_type,
        # label_ssi: self.label,
        kb_url_ssi: self.kb_url
    }
    labels.each do |lang, label|
      entity["label_#{lang}_ssi".to_sym] = label
    end
    #entity.stringify_keys!
    entity.map{|key, v| [key.to_s, v] }.to_h
  end

  def index_record
    NewseyeSolrService.add(self.to_solr)
    NewseyeSolrService.commit
  end
end
