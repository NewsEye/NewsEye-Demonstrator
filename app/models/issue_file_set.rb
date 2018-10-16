class IssueFileSet < ActiveFedora::Base

  include Hydra::Works::FileSetBehavior

  # will be used to store data on the issue (pdf combining pages, full text, etc)

  property :ocr, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :stored_searchable
  end
  property :pdf, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :stored_searchable
  end

end