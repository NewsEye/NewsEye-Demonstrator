class Issue < ActiveFedora::Base

  include Hydra::Works::WorkBehavior

  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :stored_searchable
  end
  property :date_created, predicate: ::RDF::Vocab::DC.created, multiple: false do |index|
    index.as :stored_searchable
  end
  property :language, predicate: ::RDF::Vocab::DC11.language, multiple: false do |index|
    index.as :stored_searchable, :facetable
  end
  property :publisher, predicate: ::RDF::Vocab::DC11.publisher, multiple: false do |index|
    index.as :stored_searchable
  end
  property :original_uri, predicate: ::RDF::Vocab::DC11.source, multiple: false do |index|
    index.as :stored_searchable
  end
  property :nb_pages, predicate: ::RDF::Vocab::DC11.format, multiple: false do |index|
    index.as :stored_searchable
  end
  property :text_content, predicate: ::RDF::Vocab::CNT.chars, multiple: false do |index|
    index.as :stored_searchable
  end
  property :thumbnail_url, predicate: ::RDF::Vocab::DC11.relation, multiple: false do |index|
    index.as :stored_searchable
  end
end