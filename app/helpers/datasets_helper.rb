module DatasetsHelper

  include Blacklight::SearchHelper
  include Blacklight::Configurable

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
    # get_opensearch_response :id, request_params=params, extra_controller_params={rows: 10000}

    res = search_results(params) do |builder|
      builder = SearchBuilderIds.new(self)
      builder.with(params)
      builder
    end
    JSON.parse(res[0].to_json)
  end

end
