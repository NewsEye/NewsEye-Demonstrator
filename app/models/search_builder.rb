# frozen_string_literal: true
class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  include BlacklightAdvancedSearch::AdvancedSearchBuilder
  self.default_processor_chain += [:add_advanced_parse_q_to_solr] #, :add_advanced_search_to_solr]
  include BlacklightRangeLimit::RangeLimitBuilder

  # Add a filter query to restrict the search to documents the current user has access to
  include Hydra::AccessControlsEnforcement

  self.default_processor_chain += %i[exclude_unwanted_models add_highlight]
  # self.default_processor_chain += [:fix_query]

  # Filter unwanted model in search results
  def exclude_unwanted_models(solr_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] << "has_model_ssim:(#{%w(Article Issue).join(' OR ')})"
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
    # to highlight text even when querying for exact search (when the field is not stored)
    if solr_parameters[:'qf'].index("all_text_unstemmed").nil?
      solr_parameters[:'hl.q'] = %w(fr fi de se en).map{ |lang| "all_text_t#{lang}_siv:(#{solr_parameters[:q]})" }.join(' ')
    else
      solr_parameters[:'hl.q'] = %w(fr fi de se en).map{ |lang| "all_text_unstemmed_t#{lang}_siv:(#{solr_parameters[:q]})" }.join(' ')
    end
    solr_parameters
  end

  def only_ids(solr_parameters)
    solr_parameters[:fl] = 'id'
    solr_parameters[:rows] = 500
  end

  def fix_query(solr_parameters)
    solr_parameters[:'facet.field'].uniq!
    #solr_parameters.except! :defType
  end

end
