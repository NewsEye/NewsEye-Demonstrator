class Article2 # < ApplicationRecord
  # serialize :canvases_parts, Array
  # after_save :index_record

  attr_accessor :id, :title, :all_text, :date_created, :language, :canvases_parts, :newspaper, :issue_id

  def to_solr
    solr_doc = {}
    solr_doc['id'] = self.id
    solr_doc['title_ssi'] = self.title
    solr_doc["language_ssi"] = self.language
    solr_doc["all_text_t#{self.language}_siv"] = self.all_text
    solr_doc['date_created_ssi'] = self.date_created
    solr_doc['date_created_dtsi'] = DateTime.parse(self.date_created).strftime('%Y-%m-%dT%H:%M:%SZ')
    solr_doc['level'] = '0.articles'
    solr_doc['year_isi'] = solr_doc['date_created_ssi'][0..3].to_i
    solr_doc['from_issue_ssi'] = self.issue_id
    solr_doc['member_of_collection_ids_ssim'] = self.newspaper
    solr_doc['canvases_parts_ssm'] = self.canvases_parts
    solr_doc['has_model_ssim'] = 'Article'
    solr_doc['discover_access_group_ssim'] = ['admin', 'researcher']
    solr_doc['read_access_group_ssim'] = ['admin', 'researcher']
    # solr_doc['bounds'] = "TODO"
    solr_doc
  end

  def self.from_solr id
    attrs = NewseyeSolrService.get_by_id id
    a = Article2.new
    a.id = attrs['id']
    a.title = attrs['title_ssi']
    a.language = attrs['language_ssi']
    a.all_text = attrs["all_text_t#{a.language}_siv"]
    a.date_created = attrs['date_created_ssi']
    a.issue_id = attrs['from_issue_ssi']
    a.newspaper = attrs['member_of_collection_ids_ssim'].first
    a.canvases_parts = attrs['canvases_parts_ssm']
    a
  end
end
