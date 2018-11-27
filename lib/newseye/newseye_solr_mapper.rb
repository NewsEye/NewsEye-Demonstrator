module NewseyeSolrMapper
  def self.text_de_searchable_uniq
    Solrizer::Descriptor.new(:text_de, :indexed, :stored)
  end

  def self.text_de_searchable_multi
    Solrizer::Descriptor.new(:text_de, :indexed, :stored, :multivalued)
  end

  def self.text_fi_searchable_uniq
    Solrizer::Descriptor.new(:text_fi, :indexed, :stored)
  end

  def self.text_fi_searchable_multi
    Solrizer::Descriptor.new(:text_fi, :indexed, :stored, :multivalued)
  end

  def self.text_se_searchable_uniq
    Solrizer::Descriptor.new(:text_se, :indexed, :stored)
  end

  def self.text_se_searchable_multi
    Solrizer::Descriptor.new(:text_se, :indexed, :stored, :multivalued)
  end

  def self.text_fr_searchable_uniq
    Solrizer::Descriptor.new(:text_fr, :indexed, :stored)
  end

  def self.text_fr_searchable_multi
    Solrizer::Descriptor.new(:text_fr, :indexed, :stored, :multivalued)
  end

  def self.text_en_searchable_uniq
    Solrizer::Descriptor.new(:text_en, :indexed, :stored)
  end

  def self.text_en_searchable_multi
    Solrizer::Descriptor.new(:text_en, :indexed, :stored, :multivalued)
  end

  def self.date_searchable_uniq
    Solrizer::Descriptor.new(:date, :indexed, :stored, converter: Solrizer::DefaultDescriptors.dateable_converter)
  end

  def self.string_searchable_uniq
    Solrizer::Descriptor.new(:string, :indexed, :stored)
  end

  def self.string_searchable_multi
    Solrizer::Descriptor.new(:string, :indexed, :stored, :multivalued)
  end

  def self.string_stored_uniq
    Solrizer::Descriptor.new(:string, :stored)
  end

  def self.string_stored_multi
    Solrizer::Descriptor.new(:string, :stored, :multivalued)
  end

  def self.int_searchable
    Solrizer::Descriptor.new(:integer, :stored, :indexed)
  end

  def self.int_stored
    Solrizer::Descriptor.new(:integer, :stored)
  end
end