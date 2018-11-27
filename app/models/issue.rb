class Issue < ActiveFedora::Base

  include Hydra::Works::WorkBehavior

  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.type :string
    index.as :string_searchable_uniq
  end
  property :date_created, predicate: ::RDF::Vocab::DC.created, multiple: false do |index|
    index.type :date
    index.as :date_searchable_uniq, :symbol
  end
  property :language, predicate: ::RDF::Vocab::DC11.language, multiple: false do |index|
    index.type :string
    index.as :string_searchable_uniq
  end
  property :publisher, predicate: ::RDF::Vocab::DC11.publisher, multiple: false do |index|
    index.type :string
    index.as :string_searchable_uniq
  end
  property :original_uri, predicate: ::RDF::Vocab::DC11.source, multiple: false do |index|
    index.type :string
    index.as :string_stored_uniq
  end
  property :nb_pages, predicate: ::RDF::URI('http://open.vocab.org/terms/numberOfPages'), multiple: false do |index|
    index.type :int
    index.as :int_searchable
  end
  property :all_text, predicate: ::RDF::Vocab::CNT.ContentAsText, multiple: false do |index|
    index.as :text_en_searchable_uniq, :text_fr_searchable_uniq, :text_de_searchable_uniq, :text_fi_searchable_uniq, :text_se_searchable_uniq
    # puts "######################"
    # puts self
    # if self.methods.include?(:language)
    #   case self.language
    #   when 'en'
    #     index.type :text_en
    #     index.as :text_en_searchable_uniq
    #   when 'fr'
    #     index.type :text_fr
    #     index.as :text_fr_searchable_uniq
    #   when 'de'
    #     index.type :text_de
    #     index.as :text_de_searchable_uniq
    #   when 'fi'
    #     puts 'ok fi'
    #     index.type :text_fi
    #     index.as :text_fi_searchable_uniq
    #   when 'se'
    #     index.type :text_se
    #     index.as :text_se_searchable_uniq
    #   end
    # else
    #   puts 'no method language ###################################################""'
    # end
  end
  property :thumbnail_url, predicate: ::RDF::Vocab::DC11.relation, multiple: false do |index|
    index.type :string
    index.as :string_stored_uniq
  end

  def manifest(host, with_annotations=false)
    seed = {
        '@id' => "#{host}/iiif/#{self.id}/manifest.json",
        'label' => "Issue #{self.id} manifest"
    }
    manifest = IIIF::Presentation::Manifest.new(seed)
    manifest.description = "This is a description."
    sequence = IIIF::Presentation::Sequence.new
    sequence['@id'] = "#{host}/iiif/#{self.id}/sequence/normal"
    self.ordered_members.to_a.select(&:file_set?).each do |pfs|
      sequence.canvases << pfs.canvas(host, self.id, with_annotations)
    end
    manifest.sequences << sequence
    manifest.metadata << {'label': 'Title', 'value': self.title}
    manifest.metadata << {'label': 'Date created', 'value': self.date_created}
    manifest.metadata << {'label': 'Publisher', 'value': self.publisher}
    manifest
  end

  def to_solr
    solr_doc = super
    # puts "this line was reached by #{caller.join("\n")}"
    case self.language
      when 'en'
        solr_doc.except! 'all_text_tde_si', 'all_text_tfr_si', 'all_text_tfi_si', 'all_text_tse_si'
      when 'fr'
        solr_doc.except! 'all_text_tde_si', 'all_text_ten_si', 'all_text_tfi_si', 'all_text_tse_si'
      when 'de'
        solr_doc.except! 'all_text_ten_si', 'all_text_tfr_si', 'all_text_tfi_si', 'all_text_tse_si'
      when 'fi'
        solr_doc.except! 'all_text_tde_si', 'all_text_tfr_si', 'all_text_ten_si', 'all_text_tse_si'
      when 'se'
        solr_doc.except! 'all_text_tde_si', 'all_text_tfr_si', 'all_text_tfi_si', 'all_text_ten_si'
      end
    solr_doc
  end

  def get_properties
    self.properties
  end

  def get_language
    self.language
  end
end