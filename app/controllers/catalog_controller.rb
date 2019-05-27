# -*- encoding : utf-8 -*-
require 'blacklight/catalog'

class CatalogController < ApplicationController
  # include BlacklightAdvancedSearch::Controller

  include BlacklightRangeLimit::ControllerOverride

  include Hydra::Catalog

  # These before_filters apply the hydra access controls
  before_action :enforce_show_permissions, only: :show

  before_action :handle_empty_query, only: :index

  # This applies appropriate access controls to all solr queries
  Hydra::SearchBuilder.default_processor_chain += [:add_access_controls_to_solr_params]

  # TODO add image part in "see extracts" + add position to hl : https://issues.apache.org/jira/browse/SOLR-4722
  # TODO mapping between fultext and iiif annotations (for point above + named entities)
  # TODO handle hyphenated words (information already in alto, to be checked)
  # TODO advanced search
  # TODO authorize_api_request in ApplicationController : check if query is json, else return
  # TODO check and debug import process... (check to_solr, multiple times fulltext for languages...)
  # TODO remove wiipuri
  # TODO check uusisuometar ocr data (new or old ?)
  # TODO integrate named entities inside solr as facets
  # TODO add comparison of subsets in personnal workspace for topics
  # TODO wait list of tasks (pending, partial results, finished)
  # TODO named entities on arbeiter zeitung
  # TODO see with ahmed for named entities in german
  # TODO newspaper context api (maybe explore controller ? which issue are available, calendar, etc)
  # TODO import one swedish newspaper
  # TODO open and secure solr to helsinki CS
  # TODO check OCR newlines
  #
  #
  # TODO send sarah small description of platform + images

  after_action :track_action

  configure_blacklight do |config|
    # default advanced config values
    # config.advanced_search ||= Blacklight::OpenStructWithHashAccess.new
    # # config.advanced_search[:qt] ||= 'advanced'
    # config.advanced_search[:url_key] ||= 'advanced'
    # config.advanced_search[:query_parser] ||= 'dismax'
    # config.advanced_search[:form_solr_parameters] ||= {}
    # #
    config.view.gallery.partials = [:index_header, :index]
    config.view.masonry.partials = [:index]
    config.view.slideshow.partials = [:index]


    config.show.tile_source_field = :content_metadata_image_iiif_info_ssm
    # config.show.partials.insert(1, :openseadragon)

    # config.index.thumbnail_method= :render_thumbnail # see helpers
    config.index.thumbnail_field = :thumbnail_url_ss

    config.index.document_presenter_class = MyPresenter

    ## Class for sending and receiving requests from a search index
    # config.repository_class = Blacklight::Solr::Repository
    #
    ## Class for converting Blacklight's url parameters to into request parameters for the search index
    # config.search_builder_class = ::SearchBuilder
    #
    ## Model that maps search index responses to the blacklight response model
    # config.response_model = Blacklight::Solr::Response

    ## Default parameters to send to solr for all search-like requests. See also SearchBuilder#processed_parameters
    config.default_solr_params = {
      qf: 'all_text_ten_siv all_text_tfr_siv all_text_tde_siv all_text_tfi_siv all_text_tse_siv content_tfr_siv title_tfr_siv',
      qt: 'search',
      rows: 10
    }

    config.index.title_field = 'title_ssi'
    config.index.display_type_field = 'has_model_ssim'

    config.add_facet_field solr_name('language', :string_searchable_uniq), helper_method: :convert_language_to_locale, limit: true
    config.add_facet_field solr_name('date_created', :date_searchable_uniq), helper_method: :convert_date_to_locale, label: 'Date', date: true
    config.add_facet_field 'year_isi', label: 'Year', range: { assumed_boundaries: [1800, 1950] }
    config.add_facet_field 'member_of_collection_ids_ssim', helper_method: :get_collection_title_from_id, label: 'Newspaper'
    config.add_facet_field 'has_model_ssim', helper_method: :get_display_value_from_model, label: 'Type'

    # Have BL send all facet field names to Solr, which has been the default
    # previously. Simply remove these lines if you'd rather use Solr request
    # handler defaults, or have no facets.
    config.default_solr_params[:'facet.field'] = config.facet_fields.keys
    #use this instead if you don't want to query facets marked :show=>false
    #config.default_solr_params[:'facet.field'] = config.facet_fields.select{ |k, v| v[:show] != false}.keys


    # solr fields to be displayed in the index (search results) view
    #   The ordering of the field names is the order of the display

    config.add_index_field solr_name('title', :string_searchable_uniq), label: 'Title'
    config.add_index_field solr_name('date_created', :date_searchable_uniq), helper_method: :convert_date_to_locale, label: 'Published date'
    config.add_index_field solr_name('publisher', :text_en_searchable_uniq), label: 'Publisher'
    config.add_index_field 'member_of_collection_ids_ssim', helper_method: :get_collection_title_from_id, label: 'Newspaper'
    config.add_index_field solr_name('nb_pages', :int_searchable), label: 'Number of pages'

    config.add_show_field solr_name('original_uri', :string_stored_uniq), label: 'Original URI'
    config.add_show_field solr_name('publisher', :string_searchable_uniq), label: 'Publisher'
    config.add_show_field solr_name('date_created', :date_searchable_uniq), helper_method: :convert_date_to_locale, label: 'Date created'
    config.add_show_field solr_name('nb_pages', :int_searchable), label: 'Number of pages'

    config.add_search_field 'all_fields', label: 'All Fields'


    # Now we see how to over-ride Solr request handler defaults, in this
    # case for a BL "search field", which is really a dismax aggregate
    # of Solr search fields.

    # config.add_search_field('article') do |field|
    #   # :solr_local_parameters will be sent using Solr LocalParams
    #   # syntax, as eg {! qf=$title_qf }. This is neccesary to use
    #   # Solr parameter de-referencing like $title_qf.
    #   # See: http://wiki.apache.org/solr/LocalParams
    #   field.solr_local_parameters = {
    #       fq: 'has_model_ssim:Article'
    #   }
    #   field.label = 'Article'
    # end
    #
    # config.add_search_field('issue') do |field|
    #   # :solr_local_parameters will be sent using Solr LocalParams
    #   # syntax, as eg {! qf=$title_qf }. This is neccesary to use
    #   # Solr parameter de-referencing like $title_qf.
    #   # See: http://wiki.apache.org/solr/LocalParams
    #   field.solr_local_parameters = {
    #       fq: 'has_model_ssim:Issue'
    #   }
    #   field.label = 'Article'
    # end
    #
    # config.add_search_field('author') do |field|
    #   field.solr_local_parameters = {
    #     qf: '$author_qf',
    #     pf: '$author_pf'
    #   }
    # end
    #
    # # Specifying a :qt only to show it's possible, and so our internal automated
    # # tests can test it. In this case it's the same as
    # # config[:default_solr_parameters][:qt], so isn't actually neccesary.
    # config.add_search_field('subject') do |field|
    #   field.qt = 'search'
    #   field.solr_local_parameters = {
    #     qf: '$subject_qf',
    #     pf: '$subject_pf'
    #   }
    # end

    config.add_sort_field 'score desc, date_created_dtsi desc', label: 'relevance'

    # If there are more than this many search results, no spelling ("did you
    # mean") suggestion is offered.
    config.spell_max = 5
  end

  def index
    (@response, @document_list) = search_results(params)
    # pp @response[:highlighting]
    @solr_query = search_builder.with(params).to_hash
    respond_to do |format|
      format.html { store_preferred_view }
      format.rss  { render :layout => false }
      format.atom { render :layout => false }
      format.json do
        @presenter = Blacklight::JsonPresenter.new(@response,
                                                   @document_list,
                                                   facets_from_request,
                                                   blacklight_config)
      end
      additional_response_formats(format)
      document_export_formats(format)
    end

  end

  def show
    @response, @document = fetch params[:id]
    respond_to do |format|
      format.html { setup_next_and_previous_documents }
      format.json { render json: { response: { document: @document } } }
      additional_export_formats(@document, format)
    end
  end

  def explore
    puts 'ok'
  end

  # this method allow you to change url parameters like utf8 or locale
  def search_action_url options = {}
    url_for(options.reverse_merge(action: 'index'))
  end

  protected

  # Redirect to action: index if this action is a query (not a return to home) and if there is no f or q params
  def handle_empty_query
    # @return if it's not a query
    return unless a_query?(params)
    # Remove whitespace(s) in empty query if params[:q] exists
    query = params[:q].blank? ? '' : params[:q].gsub(/\A\p{Space}*|\p{Space}*\z/, '')

    # @return if :q is not empty and if :f is not nil
    return unless query.empty? && params[:f].nil?

    return if params[:range]
    redirect_to(root_path, notice: 'Please type something or select a facet filter !')
  end

  # Detect a call to index action is a real query
  def a_query?(params)
    # @return "true" if :q or :f params are not nil
    return true if !params[:q].blank? || !params[:f].blank?
    # @return "true" if search_field *OR* utf8 params exists
    return true if %i[search_field utf8].any? { |k| params.key?(k) }
    # Otherwise, return "false"
    false
  end


  def track_action
    ahoy.track "Ran action", request.path_parameters
  end
end
