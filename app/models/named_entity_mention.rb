class NamedEntityMention < ApplicationRecord
  serialize :iiif_annotations, Array
  serialize :position, Hash
  # after_save :index_record
  belongs_to :named_entity

  def self.batch_index(nems)
    NewseyeSolrService.add(nems.map(&:to_solr))
    NewseyeSolrService.commit
  end

  def to_solr
    entity = {
        id: "entity_mention_#{self.id}",
        linked_entity_ssi: "entity_#{self.named_entity.id}",
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
    NewseyeSolrService.add(self.to_solr)
    NewseyeSolrService.commit
  end
end
