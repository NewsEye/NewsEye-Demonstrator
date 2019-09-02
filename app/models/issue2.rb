class Issue2

  # include Hydra::AccessControls::Permissions
  # include Hydra::Works::WorkBehavior


  attr_accessor :id, :title, :date_created, :language, :original_uri, :nb_pages, :all_text, :thumbnail_url, :newspaper_id, :pages, :articles,
                :to_solr_articles, :articles, :newspaper_id, :mets_path

  # after_initialize do |issue|
  #   self.to_solr_articles = false
  #   self.articles = []
  # end

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
    # manifest.metadata << {'label': 'Publisher', 'value': self.publisher}
    manifest
  end

  def to_solr
    solr_doc = {}
    solr_doc['id'] =  self.id
    solr_doc['has_model_ssim'] =  'Issue'
    solr_doc['title_ssi'] =  self.title
    solr_doc['date_created_ssi'] =  self.date_created
    solr_doc['date_created_dtsi'] =  DateTime.parse(self.date_created).strftime('%Y-%m-%dT%H:%M:%SZ')
    solr_doc['language_ssi'] =  self.language
    solr_doc['original_uri_ss'] =  self.original_uri
    solr_doc['nb_pages_isi'] =  self.nb_pages
    solr_doc['thumbnail_url_ss'] =  self.thumbnail_url
    solr_doc['member_ids_ssim'] =  self.pages.map(&:id)
    solr_doc['mets_path_ss'] = self.mets_path if self.mets_path
    solr_doc['discover_access_group_ssim'] = ['admin', 'researcher']
    solr_doc['read_access_group_ssim'] = ['admin', 'researcher']

    solr_doc['year_isi'] = solr_doc['date_created_ssi'][0..3].to_i
    solr_doc["member_of_collection_ids_ssim"] = self.newspaper_id
    case self.language
    when 'fr'
      solr_doc['all_text_tfr_siv'] = self.all_text
    when 'de'
      solr_doc['all_text_tde_siv'] = self.all_text
    when 'fi'
      solr_doc['all_text_tfi_siv'] = self.all_text
    when 'se'
      solr_doc['all_text_tse_siv'] = self.all_text
    else
      solr_doc['all_text_ten_siv'] = self.all_text
    end

    if self.to_solr_articles
      solr_doc['_childDocuments_'] = []
      self.articles.each do |article|
        solr_doc['_childDocuments_'] << article.to_solr
      end
    end
    solr_doc
  end

  def self.from_solr(id, with_pages=true, with_articles=true)
    attrs = NewseyeSolrService.get_by_id id
    i = Issue2.new
    i.id = attrs['id']
    i.language = attrs['language_ssi']
    i.newspaper_id = attrs['member_of_collection_ids_ssim'][0]
    i.title = attrs['title_ssi']
    i.date_created = attrs['date_created_ssi']
    i.original_uri = attrs['original_uri_ss']
    i.nb_pages = attrs['nb_pages_isi']
    i.thumbnail_url = attrs['thumbnail_url_ss']
    i.all_text = attrs["all_text_t#{i.language}_siv"]
    i.mets_path = attrs["mets_path_ss"] if attrs["mets_path_ss"]
    if with_pages
      i.pages = []
      attrs['member_ids_ssim'].each do |pageid|
        i.pages << PageFileSet2.from_solr(pageid)
      end
    end
    if with_articles
      i.articles = []
      NewseyeSolrService.get_articles_ids_from_issue_id(i.id).each do |art_id|
        i.articles << Article2.from_solr(art_id)
      end
    end
    i
  end

  # def get_articles
  #   self.members.to_ary.select { |v| v.instance_of?(Article) }
  # end

  def named_entity_mentions
    # entity types :
    # NamedEntity.joins(:named_entity_mentions).where('named_entity_mentions.doc_id': 'paivalehti_471957').group(:id).pluck("ne_type")
    NamedEntityMention.where(doc_id: self.id)
  end

  def named_entities
    NamedEntity.joins(:named_entity_mentions).where('named_entity_mentions.doc_id': 'paivalehti_471957').group(:id)
  end
end