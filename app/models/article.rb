class Article2

  # include Hydra::AccessControls::Permissions
  # include Hydra::Works::WorkBehavior

  attr_accessor :newspaper

  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :text_en_searchable_uniq, :text_fr_searchable_uniq, :text_de_searchable_uniq, :text_fi_searchable_uniq, :text_se_searchable_uniq
  end
  property :all_text, predicate: ::RDF::Vocab::CNT.ContentAsText, multiple: false do |index|
    index.as :text_en_searchable_uniq, :text_fr_searchable_uniq, :text_de_searchable_uniq, :text_fi_searchable_uniq, :text_se_searchable_uniq
  end
  property :date_created, predicate: ::RDF::Vocab::DC.created, multiple: false do |index|
    index.type :date
    index.as :date_searchable_uniq, :symbol
  end
  property :language, predicate: ::RDF::Vocab::DC11.language, multiple: false do |index|
    index.type :string
    index.as :string_searchable_uniq
  end
  property :canvases_parts, predicate: ::RDF::Vocab::DC.isPartOf, multiple: true do |index|
    index.as :string_stored_multi
  end

  def issue
    issues = member_of.select { |v| v.instance_of?(Issue) }
    issues[0] unless issues.empty?
  end

  def annotation_list
    annotation_list = {}
    annotation_list['@context'] = 'http://iiif.io/api/presentation/2/context.json'
    annotation_list['@id'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{issue.id}/list/article_#{self.id.split('_')[-1]}_block_level"
    annotation_list['@type'] = 'sc:AnnotationList'
    annotation_list['resources'] = []
    annotation_list['within'] = {}
    annotation_list['within']['@id'] = "#{Rails.configuration.newseye_services['host']}/iiif/#{issue.id}/layer/articles_block_level"
    annotation_list['within']['@type'] = 'sc:Layer'
    annotation_list['within']['label'] = 'OCR Layer'
    flarg = "*, [child parentFilter=level:1.* childFilter=level:2.pages.blocks limit=1000000]"
    selectors = self.canvases_parts.map{|url| url[url.rindex('#')..-1]}
    canvases_map = {}
    selectors.each { |s| canvases_map[s] = self.canvases_parts.select { |cp| cp.include? s }.first }
    ActiveFedora::SolrService.query("id:#{issue.id}_page_*", {fl: flarg}).first['_childDocuments_'].select{ |a| selectors.include? a['selector'] }.each do |annot|
      block_annot = {}
      block_annot['@type'] = 'oa:Annotation'
      block_annot['motivation'] = 'sc:painting'
      block_annot['resource'] = {}
      block_annot['resource']['@type'] = 'cnt:ContentAsText'
      block_annot['resource']['format'] = 'text/plain'
      block_annot['resource']['chars'] =  annot[annot.find{|k, hash| k.start_with?('text_')}[0]]
      block_annot['metadata'] = {}
      # block_annot['metadata']['word_confidence'] = block_text.size == 0 ? 0 : block_confidence / block_text.size
      block_annot['on'] = canvases_map[annot['selector']]
      annotation_list['resources'] << block_annot
    end
    return annotation_list
  end

  def to_solr
    solr_doc = {}
    solr_doc['id'] = self.id
    solr_doc['title_ssi'] = self.title
    solr_doc["language_ssi"] = self.language
    solr_doc["all_text_t#{self.language}_siv"] = self.all_text
    solr_doc['date_created_ssi'] = [self.date_created]
    solr_doc['date_created_dtsi'] = self.date_created
    solr_doc['level'] = '0.articles'
    solr_doc['year_isi'] = solr_doc['date_created_ssi'][0][0..3].to_i
    solr_doc['from_issue_ssi'] = self.id[0...self.id.index('_article_')]
    solr_doc['member_of_collection_ids_ssim'] = self.newspaper
    solr_doc['canvases_parts_ssm'] = self.canvases_parts
    solr_doc['has_model_ssim'] = 'Article'
    solr_doc['discover_access_group_ssim'] = ['admin', 'researcher']
    solr_doc['read_access_group_ssim'] = ['admin', 'researcher']
    case self.language
    when 'fr'
      solr_doc.except! 'all_text_tde_siv', 'all_text_ten_siv', 'all_text_tfi_siv', 'all_text_tse_siv'
      solr_doc.except! 'title_tde_siv', 'title_ten_siv', 'title_tfi_siv', 'title_tse_siv'
    when 'de'
      solr_doc.except! 'all_text_ten_siv', 'all_text_tfr_siv', 'all_text_tfi_siv', 'all_text_tse_siv'
      solr_doc.except! 'title_ten_siv', 'title_tfr_siv', 'title_tfi_siv', 'title_tse_siv'
    when 'fi'
      solr_doc.except! 'all_text_tde_siv', 'all_text_tfr_siv', 'all_text_ten_siv', 'all_text_tse_siv'
      solr_doc.except! 'title_tde_siv', 'title_tfr_siv', 'title_ten_siv', 'title_tse_siv'
    when 'se'
      solr_doc.except! 'all_text_tde_siv', 'all_text_tfr_siv', 'all_text_tfi_siv', 'all_text_ten_siv'
      solr_doc.except! 'title_tde_siv', 'title_tfr_siv', 'title_tfi_siv', 'title_ten_siv'
    else
      solr_doc.except! 'all_text_tde_siv', 'all_text_tfr_siv', 'all_text_tfi_siv', 'all_text_tse_siv' # keep english
      solr_doc.except! 'title_tde_siv', 'title_tfr_siv', 'title_tfi_siv', 'title_tse_siv'
    end
    solr_doc
  end
end
