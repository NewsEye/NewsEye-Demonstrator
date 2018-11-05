class Issue < ActiveFedora::Base

  include Hydra::Works::WorkBehavior

  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :text_en_searchable_uniq
  end
  property :date_created, predicate: ::RDF::Vocab::DC.created, multiple: false do |index|
    index.as :date_searchable_uniq, :facetable, :symbol
  end
  property :language, predicate: ::RDF::Vocab::DC11.language, multiple: false do |index|
    index.as :string_stored_uniq, :facetable
  end
  property :publisher, predicate: ::RDF::Vocab::DC11.publisher, multiple: false do |index|
    index.as :text_en_searchable_uniq
  end
  property :original_uri, predicate: ::RDF::Vocab::DC11.source, multiple: false do |index|
    index.as :string_stored_uniq
  end
  property :nb_pages, predicate: ::RDF::URI('http://open.vocab.org/terms/numberOfPages'), multiple: false do |index|
    index.as :int_searchable
  end
  property :all_text, predicate: ::RDF::Vocab::CNT.ContentAsText, multiple: false do |index|
    index.as :text_en_searchable_uniq
  end
  property :thumbnail_url, predicate: ::RDF::Vocab::DC11.relation, multiple: false do |index|
    index.as :string_stored_uniq
  end

  def manifest(host)
    seed = {
        '@id' => "#{host}/iiif/#{self.id}/manifest.json",
        'label' => "Issue #{self.id} manifest"
    }
    manifest = IIIF::Presentation::Manifest.new(seed)
    manifest.description = "This is a description."
    sequence = IIIF::Presentation::Sequence.new
    sequence['@id'] = "#{host}/iiif/#{self.id}/sequence/normal"
    self.ordered_members.to_a.select(&:file_set?).each do |pfs|
      sequence.canvases << pfs.canvas(host, self.id)
    end
    manifest.sequences << sequence
    manifest.metadata << {'label': 'Title', 'value': self.title}
    manifest.metadata << {'label': 'Date created', 'value': self.date_created}
    manifest.metadata << {'label': 'Publisher', 'value': self.publisher}
    manifest
  end
end