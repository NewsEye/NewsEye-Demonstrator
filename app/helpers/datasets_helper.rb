module DatasetsHelper

  include Blacklight::SearchHelper

  def classify_searches searches
    docs = []
    srchs = []
    searches.each do |search|
      if search.include? '/catalog/'
        docs.append search
      elsif search.include? '/catalog?'
        srchs.append search
      end
    end
    return {docs: docs, searches: srchs}
  end

  def get_ids_from_search search_url
    params = ActionController::Parameters.new(Rack::Utils.parse_nested_query URI(search_url).query)
    get_opensearch_response :id, request_params=params, extra_controller_params={rows: 1000000}
  end

end
