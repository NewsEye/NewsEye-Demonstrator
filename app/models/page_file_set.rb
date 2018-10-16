class PageFileSet < ActiveFedora::Base

  include Hydra::Works::FileSetBehavior

  property :page_number, predicate: ::RDF::Vocab::DC11.format, multiple: false do |index|
    index.as :stored_searchable
  end

end