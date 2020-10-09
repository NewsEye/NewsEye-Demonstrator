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

  def nb_compound
      self.documents.select do |doc|
          doc['type'] == 'compound'
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
        out = []
        solr_ids = self.documents.select{ |doc| doc['type'] != "compound" }.map{ |doc| doc['id'] }
        unless solr_ids.empty?
            solr_docs = NewseyeSolrService.query({q: "*:*", fq: "id:(#{solr_ids.join(' ')})", rows: 9999})
            solr_docs.map! do |solr_doc|
                solr_doc['relevancy'] = self.relevancy_for_doc solr_doc['id']
                solr_doc
            end
            out = solr_docs
        end
        compounds = self.documents.select{ |doc| doc['type'] == "compound" }
        compounds.each do |compound|
            ca = CompoundArticle.find compound['id']
            solr_doc = ca.to_solr_doc
            solr_doc['relevancy'] = compound['relevancy']
            out << solr_doc
        end
        out
    end

  def fetch_facets
    ids = self.documents.map{ |doc| doc['id']}
    NewseyeSolrService.query({q: "*:*", fq: "{!terms f=id}#{ids.join(',')}"})
  end

  def fetch_linked_entities
    docs = self.fetch_documents
    docs.map{ |doc| doc['linked_entities_ssim'] }.flatten
  end

  def get_entities
      output = {LOC: {}, PER: {}, ORG: {}, HumanProd: {}}
      solr_ids = self.documents.select{ |doc| doc['type'] != "compound" }.map{ |doc| doc['id'] }
      nems = []
      articles_ids = solr_ids.select{ |solr_id| solr_id.include? '_article_' }
      compound_parts = self.documents.select{ |doc| doc['type'] == "compound" }.map{ |doc| CompoundArticle.find(doc['id']).parts }.flatten
      part_ids = articles_ids + compound_parts
      puts part_ids
      nems += NewseyeSolrService.query({q: '*:*', fq:"article_id_ssi:(#{part_ids.join(' OR ')})", rows: 1000000}) unless part_ids.empty?
      issues_ids = solr_ids.select{ |solr_id| !solr_id.include? '_article_' }
      nems += NewseyeSolrService.query({q: '*:*', fq:"issue_id_ssi:(#{issues_ids.join(' OR ')})", rows: 1000000}) unless issues_ids.empty?

      nems.select {|ne_solr| ne_solr['type_ssi'] == "LOC"}.each do |ne_solr|
          output[:LOC][ne_solr['linked_entity_ssi']] = [] unless output[:LOC].has_key? ne_solr['linked_entity_ssi']
          output[:LOC][ne_solr['linked_entity_ssi']].append(ne_solr)
      end
      nems.select {|ne_solr| ne_solr['type_ssi'].start_with? "PER"}.each do |ne_solr|
          output[:PER][ne_solr['linked_entity_ssi']] = [] unless output[:PER].has_key? ne_solr['linked_entity_ssi']
          output[:PER][ne_solr['linked_entity_ssi']].append(ne_solr)
      end
      nems.select {|ne_solr| ne_solr['type_ssi'].start_with? "ORG"}.each do |ne_solr|
          output[:ORG][ne_solr['linked_entity_ssi']] = [] unless output[:ORG].has_key? ne_solr['linked_entity_ssi']
          output[:ORG][ne_solr['linked_entity_ssi']].append(ne_solr)
      end
      nems.select {|ne_solr| ne_solr['type_ssi'] == "HumanProd"}.each do |ne_solr|
          output[:HumanProd][ne_solr['linked_entity_ssi']] = [] unless output[:HumanProd].has_key? ne_solr['linked_entity_ssi']
          output[:HumanProd][ne_solr['linked_entity_ssi']].append(ne_solr)
      end
      output
  end
end

