class Newspaper < ActiveFedora::Base

  include Hydra::Works::CollectionBehavior

  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :stored_searchable
  end
  property :publisher, predicate: ::RDF::Vocab::DC.publisher, multiple: false do |index|
    index.as :stored_searchable
  end
  property :language, predicate: ::RDF::Vocab::DC.language, multiple: false do |index|
    index.as :stored_searchable
  end
  property :datefrom, predicate: ::RDF::Vocab::DC.date, multiple: false do |index|
    index.as :stored_searchable
  end
  property :dateto, predicate: ::RDF::Vocab::DC.date, multiple: false do |index|
    index.as :stored_searchable
  end
  property :location, predicate: ::RDF::Vocab::DC.spatial, multiple: false do |index|
    index.as :stored_searchable
  end
end