class Dataset < ApplicationRecord

    belongs_to :user, optional: true

    validates :title, uniqueness: {scope: :user_id}

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
        self.documents.index { |doc| doc['id'] == doc_id }.nil? ? false : true
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
        doc_index = self.documents.index { |doc| doc['id'] == doc_id }
        if doc_index.nil?
            -1
        else
            self.documents[doc_index]['relevancy']
        end
    end

    def add_docs docs_with_relevancy
        docs_with_relevancy.each do |document|
            doc_index = self.documents.index { |doc| doc['id'] == document[:id] }
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

    def fetch_paginated_documents(page, per_page, sort, sort_order, types)
        out = []
        docs = self.documents.select {|doc| types.include? doc['type'] }
        nb_pages = (docs.size / per_page.to_f).ceil
        nb_pages = 1 if nb_pages == 0
        if sort == "date"  # we need to preload dates for sorting before pagination
            # To modify if multiple types can be selected
            if docs[0]['type'] == "compound"
                dates = NewseyeSolrService.query({q: "*:*",
                                                  fl: "id,date_created_dtsi",
                                                  fq: "id:(#{docs.map{ |d| d['parts'][0] }.join(' ')})",
                                                  rows: 99999}).each_with_index.map{ |d,i| {id: docs[i]['id'], date_created_dtsi: d['date_created_dtsi']} }
            else
                dates = NewseyeSolrService.query({q: "*:*", fl: "id,date_created_dtsi", fq: "id:(#{docs.map{ |d| d['id'] }.join(' ')})", rows: 99999})
            end
        end
        if sort != "default"
            docs = docs.sort_by do |doc|
                case sort
                when "date"
                    Date.parse(dates.select{|d| d['id'] == doc['id']}[0]['date_created_dtsi'])
                when "relevancy"
                    doc['relevancy']
                end
            end
        end
        docs.reverse! if sort_order == "desc"
        docs.each_slice(per_page).with_index do |slice, page_idx|
            next if page_idx+1 != page
            slice.each_with_index do |doc, idx|
                doc_idx = page_idx * per_page + idx
                if doc['type'] != "compound"
                    out << doc['id']
                else
                    ca = CompoundArticle.find doc['id']
                    solr_doc = ca.to_solr_doc
                    solr_doc['relevancy'] = doc['relevancy']
                    out << solr_doc
                end
            end
        end
        solr_ids = out.select {|d| d.class == String }
        unless solr_ids.empty?
            solr_docs = NewseyeSolrService.query({q: "*:*", fq: "id:(#{solr_ids.join(' ')})", rows: 9999})
            solr_docs.map! do |solr_doc|
                solr_doc['relevancy'] = self.relevancy_for_doc solr_doc['id']
                solr_doc
            end
            out.map! do |doc|
                if doc.class == String
                    solr_docs.select {|d| d['id'] == doc }[0]
                else
                    doc
                end
            end
        end
        return {docs: out, nb_pages: nb_pages}
    end

    def fetch_documents
        out = []
        solr_ids = self.documents.select { |doc| doc['type'] != "compound" }.map { |doc| doc['id'] }
        unless solr_ids.empty?
            solr_docs = NewseyeSolrService.query({q: "*:*", fq: "id:(#{solr_ids.join(' ')})", rows: 9999})
            solr_docs.map! do |solr_doc|
                solr_doc['relevancy'] = self.relevancy_for_doc solr_doc['id']
                solr_doc
            end
            out = solr_docs
        end
        compounds = self.documents.select { |doc| doc['type'] == "compound" }
        compounds.each do |compound|
            ca = CompoundArticle.find compound['id']
            solr_doc = ca.to_solr_doc
            solr_doc['relevancy'] = compound['relevancy']
            out << solr_doc
        end
        out
    end

    def fetch_facets
        ids = self.documents.map { |doc| doc['id'] }
        NewseyeSolrService.query({q: "*:*", fq: "{!terms f=id}#{ids.join(',')}"})
    end

    def fetch_linked_entities
        docs = self.fetch_documents
        docs.map { |doc| doc['linked_entities_ssim'] }.flatten
    end

    def get_entities
        output = {LOC: {}, PER: {}, ORG: {}, HumanProd: {}}
        solr_ids = self.documents.select { |doc| doc['type'] != "compound" }.map { |doc| doc['id'] }
        nems = []
        articles_ids = solr_ids.select { |solr_id| solr_id.include? '_article_' }
        compound_parts = self.documents.select { |doc| doc['type'] == "compound" }.map { |doc| CompoundArticle.find(doc['id']).parts }.flatten
        part_ids = articles_ids + compound_parts
        nems += NewseyeSolrService.query({q: '*:*', fq: "article_id_ssi:(#{part_ids.join(' OR ')})", rows: 1000000}) unless part_ids.empty?
        issues_ids = solr_ids.select { |solr_id| !solr_id.include? '_article_' }
        nems += NewseyeSolrService.query({q: '*:*', fq: "issue_id_ssi:(#{issues_ids.join(' OR ')})", rows: 1000000}) unless issues_ids.empty?

        nems.select { |ne_solr| ne_solr['type_ssi'] == "LOC" }.each do |ne_solr|
            output[:LOC][ne_solr['linked_entity_ssi']] = [] unless output[:LOC].has_key? ne_solr['linked_entity_ssi']
            output[:LOC][ne_solr['linked_entity_ssi']].append(ne_solr)
        end
        nems.select { |ne_solr| ne_solr['type_ssi'].start_with? "PER" }.each do |ne_solr|
            output[:PER][ne_solr['linked_entity_ssi']] = [] unless output[:PER].has_key? ne_solr['linked_entity_ssi']
            output[:PER][ne_solr['linked_entity_ssi']].append(ne_solr)
        end
        nems.select { |ne_solr| ne_solr['type_ssi'].start_with? "ORG" }.each do |ne_solr|
            output[:ORG][ne_solr['linked_entity_ssi']] = [] unless output[:ORG].has_key? ne_solr['linked_entity_ssi']
            output[:ORG][ne_solr['linked_entity_ssi']].append(ne_solr)
        end
        nems.select { |ne_solr| ne_solr['type_ssi'] == "HumanProd" }.each do |ne_solr|
            output[:HumanProd][ne_solr['linked_entity_ssi']] = [] unless output[:HumanProd].has_key? ne_solr['linked_entity_ssi']
            output[:HumanProd][ne_solr['linked_entity_ssi']].append(ne_solr)
        end
        output
    end
end

