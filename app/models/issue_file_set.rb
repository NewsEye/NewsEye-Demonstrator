class IssueFileSet < ActiveFedora::Base

  include Hydra::Works::FileSetBehavior

  property :ocr, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :stored_searchable
  end
  property :pdf, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :stored_searchable
  end
  property :thumbnail_uri, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :stored_searchable
  end

end