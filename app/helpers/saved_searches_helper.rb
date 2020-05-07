module SavedSearchesHelper

  def get_doc_ids search
    search_params = Rack::Utils.parse_nested_query search.query_url[search.query_url.index("/catalog?")+9..-1]
    search_params = Blacklight::Solr::Request.new search_params
    sb = SearchBuilder.new self
    sb = sb.with search_params
    sb = sb.except :add_facetting_to_solr, :add_paging_to_solr, :add_facet_paging_to_solr, :add_solr_fields_to_query, :add_highlight, :add_access_controls_to_solr_params
    sb = sb.append :only_ids
    sb.processor_chain.each do |method| puts method; sb.send(method, search_params) end
    solr = Blacklight::Solr::Repository.new(self.blacklight_config)
    resp = solr.search(sb)
    resp['response']['docs'].map{ |doc| doc['id'] }
  end

  def get_solr_params search_url
    search_params = Rack::Utils.parse_nested_query search_url[search_url.index("/catalog?")+9..-1]
    search_params = Blacklight::Solr::Request.new search_params
    sb = SearchBuilder.new self
    sb = sb.with search_params
    sb = sb.except :add_facetting_to_solr, :add_paging_to_solr, :add_facet_paging_to_solr, :add_solr_fields_to_query, :add_highlight, :add_access_controls_to_solr_params
    sb = sb.append :only_ids
    sb.processor_chain.each do |method| puts method; sb.send(method, search_params) end
    sb.to_h
  end

end
