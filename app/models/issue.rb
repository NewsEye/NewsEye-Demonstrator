class Issue < ActiveFedora::Base

  include Hydra::AccessControls::Permissions
  include Hydra::Works::WorkBehavior


  attr_accessor :to_solr_articles, :articles

  after_initialize do |issue|
    self.to_solr_articles = false
    self.articles = []
  end

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
  property :contributor, predicate: ::RDF::Vocab::DC11.contributor, multiple: false do |index|
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
  end

  property :thumbnail_url, predicate: ::RDF::Vocab::DC11.relation, multiple: false do |index|
    index.type :string
    index.as :string_stored_uniq
  end

  property :location, predicate: ::RDF::Vocab::DC11.coverage, multiple: false do |index|
    index.type :string
    index.as :string_searchable_uniq
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
    ###
    # for each article of the issue :
    # article = nil
    # range = IIIF::Presentation::Range.new
    # range['@id'] = "#{host}/iiif/#{self.id}/range/#{article.id}"
    # range['label'] = article.title
    # # for each textblock
    # range.canvases << "#{host}/iiif/book1/canvas/p3#xywh=0,0,750,300"
    # manifest.structures << range
    ###
    manifest.metadata << {'label': 'Title', 'value': self.title}
    manifest.metadata << {'label': 'Date created', 'value': self.date_created}
    manifest.metadata << {'label': 'Publisher', 'value': self.publisher}
    manifest
  end

  def to_solr
    solr_doc = super
    case self.language
      when 'fr'
        solr_doc.except! 'all_text_tde_siv', 'all_text_ten_siv', 'all_text_tfi_siv', 'all_text_tse_siv'
      when 'de'
        solr_doc.except! 'all_text_ten_siv', 'all_text_tfr_siv', 'all_text_tfi_siv', 'all_text_tse_siv'
      when 'fi'
        solr_doc.except! 'all_text_tde_siv', 'all_text_tfr_siv', 'all_text_ten_siv', 'all_text_tse_siv'
      when 'se'
        solr_doc.except! 'all_text_tde_siv', 'all_text_tfr_siv', 'all_text_tfi_siv', 'all_text_ten_siv'
    else
      solr_doc.except! 'all_text_tde_siv', 'all_text_tfr_siv', 'all_text_tfi_siv', 'all_text_tse_siv' # keep english
    end

    if self.to_solr_articles
      solr_doc['_childDocuments_'] = []
      self.articles.each do |article|
        solr_doc['_childDocuments_'] << article
      end
    end
    solr_doc
  end

  def get_properties
    self.properties
  end

  def get_language
    self.language
  end

  def pages
    ordered_members.select { |v| v.instance_of?(PageFileSet) }
  end

  def articles
    members.select { |v| v.instance_of?(Article) }
  end
end