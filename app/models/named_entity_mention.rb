class NamedEntityMention #< ApplicationRecord
  # serialize :iiif_annotations, Array
  # serialize :position, Hash
  # after_save :index_record
  # belongs_to :named_entity

  attr_accessor :id, :linked_entity_id, :ne_type, :issue_id, :article_id, :mention, :iiif_annotations, :issue_position, :article_position, :detection_confidence, :linking_confidence, :stance

  def to_solr
    entity = {
        id: "#{self.id}",
        linked_entity_ssi: "#{self.linked_entity_id}",
        issue_id_ssi: self.issue_id,
        type_ssi: self.ne_type,
        article_id_ssi: self.article_id,
        mention_ssi: self.mention,
        selector_ssim: self.iiif_annotations,
        issue_index_start_isi: self.issue_position[:start],
        issue_index_end_isi: self.issue_position[:end],
        article_index_start_isi: self.article_position[:start],
        article_index_end_isi: self.article_position[:end],
        detection_confidence_fsi: self.detection_confidence,
        linking_confidence_fsi: self.linking_confidence,
        stance_fsi: self.stance
    }
    #entity.stringify_keys!
    entity.map{|key, v| [key.to_s, v] }.to_h
  end

  def self.batch_index nems
    docs = nems.map(&:to_solr)
    puts NewseyeSolrService.add docs
    puts NewseyeSolrService.commit
  end

end
