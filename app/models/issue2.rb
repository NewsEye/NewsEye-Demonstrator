class Issue2

  # include Hydra::AccessControls::Permissions
  # include Hydra::Works::WorkBehavior


  attr_accessor :id, :title, :date_created, :language, :original_uri, :nb_pages, :all_text, :thumbnail_url, :newspaper_id, :pages, :articles,
                :to_solr_articles, :articles, :newspaper_id, :mets_path, :word_annots

  # after_initialize do |issue|
  #   self.to_solr_articles = false
  #   self.articles = []
  # end

  def manifest(host, with_annotations: false)
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
    unless articles.nil?
      articles.each do |article|
        range = IIIF::Presentation::Range.new
        range['@id'] = "#{host}/iiif/#{self.id}/range/#{article.id}"
        range['label'] = article.title
        range.canvases.push(*article.canvases_parts)
        range['contentLayer'] = "#{host}/iiif/#{self.id}/layer/#{article.id}"
        manifest.structures << range
      end
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
    solr_doc['discover_access_group_ssim'] = ['admin', 'researcher', 'registered']
    if self.language == "fi" or self.language == "se"
      solr_doc['read_access_group_ssim'] = ['admin', 'researcher']
    else
      solr_doc['read_access_group_ssim'] = ['admin', 'researcher', 'registered']
    end

    solr_doc['year_isi'] = solr_doc['date_created_ssi'][0..3].to_i
    solr_doc["member_of_collection_ids_ssim"] = self.newspaper_id
    solr_doc["all_text_t#{self.language}_siv"] = self.all_text

    if self.to_solr_articles
      solr_doc['_childDocuments_'] = []
      self.articles.each do |article|
        solr_doc['_childDocuments_'] << article.to_solr
      end
    end
    solr_doc
  end

  def self.from_solr(id, with_pages: true, with_articles: true, with_word_annots: false)
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
      ids = NewseyeSolrService.get_articles_ids_from_issue_id(i.id)
      solr_docs = NewseyeSolrService.query({q: "*:*", fq: "id:(#{ids.join(' ')})", rows: 9999})
      solr_docs.each do |solr_doc|
        i.articles << Article2.from_solr_doc(solr_doc)
      end
    end
    if with_word_annots
      i.word_annots = []
      (1..i.nb_pages).each do |pagenum|
        puts pagenum
        NewseyeSolrService.query({q: "id:#{id}_#{pagenum}_word*", rows: 9999999}).each do |annot|
          block_annot = {}
          block_annot['@type'] = 'oa:Annotation'
          block_annot['motivation'] = 'sc:painting'
          block_annot['resource'] = {}
          block_annot['resource']['@type'] = 'cnt:ContentAsText'
          block_annot['resource']['format'] = 'text/plain'
          block_annot['resource']['chars'] =  annot[annot.find{|k, hash| k.start_with?('text_')}[0]]
          block_annot['metadata'] = {}
          # block_annot['metadata']['word_confidence'] = block_text.size == 0 ? 0 : block_confidence / block_text.size
          block_annot['on'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{id}/canvas/page_#{pagenum}#{annot['selector']}"
          i.word_annots << block_annot
        end
      end
    end
    i
  end

  def self.from_solr_doc(solr_doc, with_pages: true, with_articles: true, with_word_annots: false)
    i = Issue2.new
    i.id = solr_doc['id']
    i.language = solr_doc['language_ssi']
    i.newspaper_id = solr_doc['member_of_collection_ids_ssim'][0]
    i.title = solr_doc['title_ssi']
    i.date_created = solr_doc['date_created_ssi']
    i.original_uri = solr_doc['original_uri_ss']
    i.nb_pages = solr_doc['nb_pages_isi']
    i.thumbnail_url = solr_doc['thumbnail_url_ss']
    i.all_text = solr_doc["all_text_t#{i.language}_siv"]
    i.mets_path = solr_doc["mets_path_ss"] if solr_doc["mets_path_ss"]
    if with_pages
      i.pages = []
      solr_doc['member_ids_ssim'].each do |pageid|
        i.pages << PageFileSet2.from_solr(pageid)
      end
    end
    if with_articles
      i.articles = []
      ids = NewseyeSolrService.get_articles_ids_from_issue_id(i.id)
      solr_article_docs = NewseyeSolrService.query({q: "*:*", fq: "id:(#{ids.join(' ')})", rows: 9999})
      solr_article_docs.each do |solr_article_doc|
        i.articles << Article2.from_solr_doc(solr_article_doc)
      end
    end
    if with_word_annots
      i.word_annots = []
      (1..i.nb_pages).each do |pagenum|
        puts pagenum
        NewseyeSolrService.query({q: "id:#{id}_#{pagenum}_word*", rows: 9999999}).each do |annot|
          block_annot = {}
          block_annot['@type'] = 'oa:Annotation'
          block_annot['motivation'] = 'sc:painting'
          block_annot['resource'] = {}
          block_annot['resource']['@type'] = 'cnt:ContentAsText'
          block_annot['resource']['format'] = 'text/plain'
          block_annot['resource']['chars'] =  annot[annot.find{|k, hash| k.start_with?('text_')}[0]]
          block_annot['metadata'] = {}
          # block_annot['metadata']['word_confidence'] = block_text.size == 0 ? 0 : block_confidence / block_text.size
          block_annot['on'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{id}/canvas/page_#{pagenum}#{annot['selector']}"
          i.word_annots << block_annot
        end
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