# frozen_string_literal: true
class SearchBuilderIds < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  # include BlacklightAdvancedSearch::AdvancedSearchBuilder
  # self.default_processor_chain += [:add_advanced_parse_q_to_solr, :add_advanced_search_to_solr]
  include BlacklightRangeLimit::RangeLimitBuilder

  # Add a filter query to restrict the search to documents the current user has access to
  include Hydra::AccessControlsEnforcement

  self.default_processor_chain += %i[set_fl_id]


  def set_fl_id(solr_parameters)
    solr_parameters[:fl] = "id"
    solr_parameters[:rows] = 50
  end

end
