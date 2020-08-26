module NewseyeVariables
  class DateSpan
    MinDate, MaxDate = NewseyeSolrService.get_min_max_dates
  end
  class FacetsCounts
    InitialFacets = NewseyeSolrService.get_facets_counts
  end
end