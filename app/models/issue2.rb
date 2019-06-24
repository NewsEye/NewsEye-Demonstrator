class Issue2

  # include Hydra::AccessControls::Permissions
  # include Hydra::Works::WorkBehavior


  attr_accessor :id, :title, :date_created, :language, :original_uri, :nb_pages, :all_text, :thumbnail_url, :newspaper_id, :pages, :articles,
                :to_solr_articles, :articles, :newspaper_id

  # after_initialize do |issue|
  #   self.to_solr_articles = false
  #   self.articles = []
  # end

  def self.load_issue(id, get_pages=false, get_articles=false)
    Rails.cache.fetch(id) do
      issue_json = NewseyeSolrService.get_by_id id
      puts issue_json
      issue = Issue2.new
      issue.id = id
      issue.title = issue_json['title_ssi']
      issue.date_created = Date.parse issue_json['date_created_dtsi']
      issue.language = issue_json['language_ssi']
      issue.original_uri = issue_json['original_uri_ss']
      issue.nb_pages = issue_json['nb_pages_isi']
      issue.all_text = issue_json["all_text_t#{issue.language}_siv"]
      issue.thumbnail_url = issue_json['thumbnail_url_ss']
      issue.newspaper_id = issue_json['member_of_collection_ids_ssim']
      if get_pages
        issue.pages = issue_json['object_ids_ssim'].map { |pfs_id|
          PageFileSet2.load_page_file_set pfs_id
        }
      end
      if get_articles

      end
      issue
    end
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
    pages.each do |pfs|
      sequence.canvases << pfs.canvas(host, self.id, with_annotations)
    end
    manifest.sequences << sequence

    articles.each do |article|
      range = IIIF::Presentation::Range.new
      range['@id'] = "#{host}/iiif/#{self.id}/range/#{article.id}"
      range['label'] = article.title
      range.canvases.push(*article.canvases_parts)
      range['contentLayer'] = "#{host}/iiif/#{self.id}/layer/#{article.id}"
      manifest.structures << range
    end
    manifest.metadata << {'label': 'Title', 'value': self.title}
    manifest.metadata << {'label': 'Date created', 'value': self.date_created}
    manifest.metadata << {'label': 'Publisher', 'value': self.publisher}
    manifest
  end

  def to_solr
    solr_doc = super
    solr_doc['year_isi'] = solr_doc['date_created_ssim'][0][0..3].to_i
    solr_doc["member_of_collection_ids_ssim"] = self.newspaper_id
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
        solr_doc['_childDocuments_'] << article.to_solr
      end
    end
    solr_doc
  end

  def get_articles
    self.members.to_ary.select { |v| v.instance_of?(Article) }
  end

  def named_entity_mentions
    # entity types :
    # NamedEntity.joins(:named_entity_mentions).where('named_entity_mentions.doc_id': 'paivalehti_471957').group(:id).pluck("ne_type")
    NamedEntityMention.where(doc_id: self.id)
  end

  def named_entities
    NamedEntity.joins(:named_entity_mentions).where('named_entity_mentions.doc_id': 'paivalehti_471957').group(:id)
  end
end