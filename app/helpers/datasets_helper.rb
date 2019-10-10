module DatasetsHelper

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

  def get_ids_from_search(search_url, dataset_user)
    klass = Class.new do
      define_method :initialize  do |user|
        @user = user
      end
      define_method :blacklight_config do
        CatalogController.blacklight_config
      end
      define_method :current_ability do
        Ability.new(@user)
      end
    end

    search_params = ActionController::Parameters.new(Rack::Utils.parse_nested_query URI(search_url).query)
    builder = SearchBuilderIds.new(klass.new(dataset_user))
    builder.with(search_params)
    results = NewseyeSolrService.query builder.to_h
    results.map { |r| r['id'] }
  end

end
