class Article# < ApplicationRecord
  # serialize :canvases_parts, Array
  # after_save :index_record

  attr_accessor :id, :title, :all_text, :date_created, :language, :canvases_parts, :newspaper, :issue_id

  def to_solr
    solr_doc = {}
    solr_doc['id'] = self.id
    solr_doc['title_ssi'] = self.title
    solr_doc["language_ssi"] = self.language
    solr_doc["all_text_t#{self.language}_siv"] = self.all_text
    solr_doc['date_created_ssim'] = [self.date_created]
    solr_doc['date_created_dtsi'] = self.date_created
    solr_doc['level'] = '0.articles'
    solr_doc['year_isi'] = solr_doc['date_created_ssim'][0][0..3].to_i
    solr_doc['from_issue_ssi'] = self.issue_id
    solr_doc['member_of_collection_ids_ssim'] = self.newspaper
    solr_doc['canvases_parts_ssm'] = self.canvases_parts
    solr_doc['has_model_ssim'] = 'Article'
    solr_doc['discover_access_group_ssim'] = ['admin', 'researcher']
    solr_doc['read_access_group_ssim'] = ['admin', 'researcher']
    solr_doc
  end

  def self.get_article(id)
    ActiveFedora::SolrService.query("id:#{id}")["response"]["docs"]
  end

  def index_record
    ActiveFedora::SolrService.instance.conn.add(self.to_solr)
    ActiveFedora::SolrService.instance.conn.commit
  end
end
