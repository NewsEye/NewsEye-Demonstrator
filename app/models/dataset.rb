class Dataset < ApplicationRecord

  belongs_to :user, optional: true

  validates :title, uniqueness: { scope: :user_id }

  # serialize :searches, Array
  # serialize :articles, Array
  # serialize :issues, Array


  def get_ids
    ids = []
    self.searches.each do |search|
      ids += ApplicationController.helpers.get_ids_from_search(search, self.user)
    end
    ids.concat self.articles
    ids.concat self.issues
    ids.uniq
  end

  def contains doc_id
    # Dataset.where('documents @> ?', [{id: 'idididid'}].to_json).pluck :id
    #self.documents.each do |doc|
    #  return true if doc['id'] == doc_id
    #end
    #return false
    self.documents.index{|doc| doc['id'] == doc_id}.nil? ? false : true
  end

  def nb_articles
    self.documents.select do |doc|
      doc['type'] == 'article'
    end.size
  end

  def nb_issues
    self.documents.select do |doc|
      doc['type'] == 'issue'
    end.size
  end

  def relevancy_for_doc doc_id
    doc_index = self.documents.index{ |doc| doc['id'] == doc_id }
    if doc_index.nil?
      -1
    else
      self.documents[doc_index]['relevancy']
    end
  end

  def add_docs docs_with_relevancy
    docs_with_relevancy.each do |document|
      doc_index = self.documents.index{ |doc| doc['id'] == document[:id] }
      if doc_index.nil?
        self.documents << document if document[:relevancy] != -1
      else
        if document[:relevancy] == -1
          self.documents.delete_at doc_index
        else
          self.documents[doc_index]['relevancy'] = document[:relevancy]
        end
      end
    end
  end

  def fetch_documents
    ids = self.documents.map{ |doc| doc['id']}
    return [] if ids.empty?
    solr_docs = NewseyeSolrService.query({q: "*:*", fq: "id:(#{ids.join(' ')})", rows: 9999})
    solr_docs.map! do |solr_doc|
      solr_doc['relevancy'] = self.relevancy_for_doc solr_doc['id']
      solr_doc
    end
  end

  def fetch_facets
    ids = self.documents.map{ |doc| doc['id']}
    NewseyeSolrService.query({q: "*:*", fq: "{!terms f=id}#{ids.join(',')}"})
  end

  def fetch_linked_entities
    docs = self.fetch_documents
    docs.map{ |doc| doc['linked_entities_ssim'] }.flatten
  end
end

