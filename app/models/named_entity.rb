class NamedEntity < ApplicationRecord
  has_many :named_entity_mentions

  after_save :index_record

  def to_solr
    entity = {
        id: "entity_#{self.id}",
        entity_type_ssi: self.ne_type,
        label_ssi: self.label,
        kb_url_ssi: self.kb_url
    }
    entity.stringify_keys!
  end

  def index_record
    ActiveFedora::SolrService.instance.conn.add(self.to_solr)
    ActiveFedora::SolrService.instance.conn.commit
  end
end
