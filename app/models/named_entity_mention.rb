class NamedEntityMention < ApplicationRecord
  serialize :iiif_annotations, Array
  serialize :position, Hash
  after_save :index_record
  belongs_to :named_entity

  def to_solr
    entity = {
        id: "entity_#{self.id}",
        doc_id_ssi: self.doc_id,
        mention_ssi: self.mention,
        selector_ssim: self.iiif_annotations,
        index_start_isi: self.position[:start],
        index_end_isi: self.position[:end],
        detection_confidence_fsi: self.detection_confidence,
        linking_confidence_fsi: self.linking_confidence,
        stance_fsi: self.stance
    }
    entity.stringify_keys!
  end

  def index_record
    ActiveFedora::SolrService.instance.conn.add(self.to_solr)
    ActiveFedora::SolrService.instance.conn.commit
  end
end
