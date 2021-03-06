# frozen_string_literal: true
class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  # include BlacklightAdvancedSearch::AdvancedSearchBuilder
  # self.default_processor_chain += [:add_advanced_parse_q_to_solr, :add_advanced_search_to_solr]
  include BlacklightRangeLimit::RangeLimitBuilder

  # Add a filter query to restrict the search to documents the current user has access to
  include Hydra::AccessControlsEnforcement

  self.default_processor_chain += %i[exclude_unwanted_models add_highlight]

  # Filter unwanted model in search results
  def exclude_unwanted_models(solr_parameters)
    solr_parameters[:fq] ||= []
    params = []
    to_exclude = %w(
        ActiveFedora::IndirectContainer
        ActiveFedora::Aggregation::Proxy
        ActiveFedora::DirectContainer
        ActiveFedora::Aggregation::ListSource
        Hydra::AccessControl
        Hydra::AccessControls::Permission
        PageFileSet
        Newspaper
    )
    to_exclude.each do |model|
      params << "-has_model_ssim:\"#{model}\""
    end
    params << "-level:2.pages.blocks"
    params << "-level:3.pages.blocks.lines"
    params << "-level:4.pages.blocks.lines.words"
    # params << "-level:0.articles"
    solr_parameters[:fq] << "(#{params.join(' AND ')})"
  end

  def add_highlight(solr_parameters)
    solr_parameters[:'hl'] = 'on'
    solr_parameters[:'hl.method'] = 'unified'
    solr_parameters[:'hl.fl'] = 'all_text_* content_*'
    solr_parameters[:'hl.snippets'] = 10
    solr_parameters[:'hl.fragsize'] = 150
    solr_parameters[:'hl.simple.pre'] = '<span style="background-color: red; color: white;">'
    solr_parameters[:'hl.simple.post'] = '</span>'
    solr_parameters[:'hl.maxAnalyzedChars'] = 10000000
  end

end
