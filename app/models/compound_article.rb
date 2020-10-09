class CompoundArticle < ActiveRecord::Base

  belongs_to :user, optional: false


  def to_solr_doc # not indexed in solr but used to export and display datasets
      issue_info = NewseyeSolrService.query({
                                                q: "*:*",
                                                fq: "id:#{self.issue}",
                                                fl: ["id", "language_ssi", "date_created_dtsi", "member_of_collection_ids_ssim", "thumbnail_url_ss"],
                                                rows: 1
                                            })[0]
      solr_doc = {}
      solr_doc['id'] = self.id
      solr_doc['from_issue_ssi'] = issue_info["id"]
      solr_doc['language_ssi'] = issue_info["language_ssi"]
      solr_doc['title_ssi'] = "Compound: #{self.title}"
      solr_doc['date_created_dtsi'] = issue_info["date_created_dtsi"]
      solr_doc['thumbnail_url_ss'] = issue_info["thumbnail_url_ss"]
      solr_doc['member_of_collection_ids_ssim'] = issue_info["member_of_collection_ids_ssim"]
      text_parts = NewseyeSolrService.query({
                                                q: "*:*",
                                                fq: "id:(#{self.parts.join(" ")})",
                                                fl: ["id", "all_text_t#{solr_doc['language_ssi']}_siv", "thumbnail_url_ss"],
                                                rows: 9999
                                            })
      solr_doc['thumbnail_url_ss_list'] = text_parts.map{|d| d["thumbnail_url_ss"] }.join("\n")
      solr_doc["all_text_t#{solr_doc['language_ssi']}_siv"] = text_parts.map{|d| d["all_text_t#{solr_doc['language_ssi']}_siv"] }.join("\n")
      solr_doc["article_parts_ssim"] = text_parts.map{|d| d["id"] }
      solr_doc
  end

end
