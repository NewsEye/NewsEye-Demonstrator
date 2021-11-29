class Dataset < ActiveRecord::Base

    # after_find :nb_issues, :nb_articles
    belongs_to :user, optional: false
    validates :title, length: { minimum: 1 }

    def add_documents(documents_ids)
        existing = []
        documents_ids.each do |doc_id|
            if self.documents.any?{ |doc| doc['id'] == doc_id }
                existing << doc_id
            else
                doc_type = doc_id.index("_article_").nil? ? "issue" : "article"
                self.documents << {id: doc_id, type: doc_type}
            end
        end
        self.save
        return existing
    end

    def add_compound(compound_id)
        existing = []
        if self.documents.any?{ |doc| doc['id'] == compound_id }
            existing << compound_id
        else
            doc_type = "compound"
            self.documents << {id: compound_id, type: doc_type}
        end
        self.save
        return existing
    end

    def remove_documents(documents_ids)
        self.documents.delete_if{ |elt| documents_ids.include? elt['id'] }
        self.save
    end

    def contains doc_id
        self.documents.index { |doc| doc['id'] == doc_id }.nil? ? false : true
    end

    def nb_issues
        self.documents.select do |doc|
            doc['type'] == 'issue'
        end.size
    end

    def nb_articles
        self.documents.select do |doc|
            doc['type'] == 'article'
        end.size
    end

    def nb_compound_articles
        self.documents.select do |doc|
            doc['type'] == 'compound'
        end.size
    end

    def fetch_paginated_documents(page, per_page, sort, sort_order, type, recursive=false)
        docs = self.documents.select {|doc| type == "all" || doc['type'] == type }

        nb_pages = (docs.size / per_page.to_f).ceil
        nb_pages = 1 if nb_pages == 0
        sort = (sort == "default") ? "score" : sort
        solr_docs = nil

        compounds_ids = docs.select{|d| d['type'] == "compound" }.map{ |d| d['id'] }
        compound_articles = CompoundArticle.find(compounds_ids)


        solr_ids = docs.select{|d| d['type'] != "compound" }.map{ |d| d['id'] }
        unless solr_ids.empty?
            solr_docs = SolrSearcher.query({
                                             q: "*:*",
                                             fq: "id:(#{solr_ids.join(' ')})",
                                             rows: per_page,
                                             sort: "#{sort} #{sort_order}",
                                             start: (page-1)*per_page
                                           })['response']['docs']
            solr_docs.map! do |solr_doc|
                if solr_doc['id'].index("_article_").nil?
                    Issue.from_solr_doc solr_doc
                else
                    Article.from_solr_doc solr_doc
                end
            end
        end
        if recursive and page < nb_pages and !solr_docs.nil?
            solr_docs = solr_docs.concat fetch_paginated_documents(page+1, per_page, sort, sort_order, type, true)[:docs]
        end
        return {docs: solr_docs.nil? ? compound_articles : solr_docs+compound_articles, nb_pages: nb_pages}
    end

    def named_entities
        article_ids = self.documents.select {|d| d['type'] == 'article' }.map{|d| d['id']}
        issue_ids = self.documents.select {|d| d['type'] == 'issue' }.map{|d| d['id']}
        nems = []
        nems = SolrSearcher.query({q: "*:*", fq: "article_id_ssi:(#{article_ids.join(' OR ')})", rows: 1000000})['response']['docs'] unless article_ids.empty?
        nems += SolrSearcher.query({q: "*:*", fq: "issue_id_ssi:(#{issue_ids.join(' OR ')})", rows: 1000000})['response']['docs'] unless issue_ids.empty?
        output = {LOC: {}, PER: {}, ORG: {}, HumanProd: {}}
        nems.select {|ne_solr| ne_solr['type_ssi'] == "LOC"}.each do |ne_solr|
            output[:LOC][ne_solr['linked_entity_ssi']] = [] unless output[:LOC].has_key? ne_solr['linked_entity_ssi']
            output[:LOC][ne_solr['linked_entity_ssi']].append(ne_solr)
        end
        nems.select {|ne_solr| ne_solr['type_ssi'] == "PER"}.each do |ne_solr|
            output[:PER][ne_solr['linked_entity_ssi']] = [] unless output[:PER].has_key? ne_solr['linked_entity_ssi']
            output[:PER][ne_solr['linked_entity_ssi']].append(ne_solr)
        end
        nems.select {|ne_solr| ne_solr['type_ssi'] == "ORG"}.each do |ne_solr|
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
