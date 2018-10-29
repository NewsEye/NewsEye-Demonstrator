class PageFileSet < ActiveFedora::Base

  include Hydra::Works::FileSetBehavior

  property :page_number, predicate: ::RDF::Vocab::SCHEMA.pagination, multiple: false do |index|
    index.as :int_searchable
  end

  property :width, predicate: ::RDF::Vocab::MA.frameWidth, multiple: false do |index|
    index.as :int_stored
  end

  property :height, predicate: ::RDF::Vocab::MA.frameHeight, multiple: false do |index|
    index.as :int_stored
  end

  property :mime_type, predicate: ::RDF::Vocab::DC11.format, multiple: false do |index|
    index.as :string_searchable_uniq
  end

  def display_image
    IIIFManifest::DisplayImage.new(id,
                                   width: self.width,
                                   height: self.height,
                                   format: self.mime_type,
                                   iiif_endpoint: endpoint
    )
  end

  private

  def endpoint
    IIIFManifest::IIIFEndpoint.new("http://localhost:3000/iiif/#{self.id}",
                                   profile: "http://iiif.io/api/image/2/level2.json")
  end

end