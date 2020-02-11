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

  def get_info_from_relevancy relevancy
    case relevancy
    when 0
      []
    when 1
      ['light', 'Somewhat relevant']
    when 2
      ['info', 'Relevant']
    when 3
      ['primary', 'Very relevant']
    end
  end

  def get_relevancy_text relevancy
    case relevancy
    when -1
      "Deleted"
    when 0
      "Not relevant"
    when 1
      'Somewhat relevant'
    when 2
      'Relevant'
    when 3
      'Very relevant'
    end
  end

end
