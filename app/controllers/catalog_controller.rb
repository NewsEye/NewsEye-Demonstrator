# -*- encoding : utf-8 -*-

class CatalogController < ApplicationController
  include BlacklightAdvancedSearch::Controller
  # include BlacklightAdvancedSearch::Controller

  include BlacklightRangeLimit::ControllerOverride

  include Hydra::Catalog

  # These before_filters apply the hydra access controls
  # before_action :enforce_show_permissions, only: :show

  before_action :handle_empty_query, only: :index

  # This applies appropriate access controls to all solr queries
  # Hydra::SearchBuilder.default_processor_chain += [:add_access_controls_to_solr_params]

  # TODO add image part in "see extracts" + add position to hl : https://issues.apache.org/jira/browse/SOLR-4722
  # TODO advanced search
  # TODO check uusisuometar ocr data (new or old ?)
  # TODO add comparison of subsets in personnal workspace for topics
  # TODO newspaper context api (maybe explore controller ? which issue are available, calendar, etc)

  # after_action :track_action

  configure_blacklight do |config|
    # default advanced config values
    config.advanced_search ||= Blacklight::OpenStructWithHashAccess.new
    # config.advanced_search[:qt] ||= 'advanced'
    config.advanced_search[:url_key] ||= 'advanced'
    config.advanced_search[:query_parser] ||= 'dismax'
    config.advanced_search[:form_solr_parameters] ||= {}

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
        #qf: 'all_text_ten_siv all_text_tfr_siv all_text_tde_siv all_text_tfi_siv all_text_tse_siv title_tfr_siv',
        qf: %w(all_text_unstemmed_ten_siv^3 all_text_unstemmed_tfr_siv^3 all_text_unstemmed_tfi_siv^3 all_text_unstemmed_tse_siv^3 all_text_unstemmed_tde_siv^3 all_text_ten_siv all_text_tfr_siv all_text_tfi_siv all_text_tse_siv all_text_tde_siv title_ten_siv title_tfr_siv title_tfi_siv title_tde_siv title_tse_siv).join(' '),
        qt: 'search',
        rows: 10
    }

    config.index.title_field = 'title_ssi'
    config.index.display_type_field = 'has_model_ssim'

    config.add_facet_field solr_name('language', :string_searchable_uniq), helper_method: :convert_language_to_locale, limit: true, tag: "langtag", ex: "langtag"
    config.add_facet_field solr_name('date_created', :date_searchable_uniq), helper_method: :convert_date_to_locale, label: 'Date', limit: 5, date: true
    config.add_facet_field 'year_isi', label: 'Year', range: true #{ assumed_boundaries: [1800, 1950] }
    config.add_facet_field 'member_of_collection_ids_ssim', helper_method: :get_collection_title_from_id, label: 'Newspaper', tag: "collectag", ex: "collectag"
    config.add_facet_field 'has_model_ssim', helper_method: :get_display_value_from_model, label: 'Type'

    config.add_facet_fields_to_solr_request!

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
    config.add_sort_field 'date_created_dtsi desc, score desc', label: 'date ⬆'
    config.add_sort_field 'date_created_dtsi asc, score desc', label: 'date ⬇'

    # If there are more than this many search results, no spelling ("did you
    # mean") suggestion is offered.
    config.spell_max = 5
  end

  def index
    (@response, @document_list) = search_results(params)
    respond_to do |format|
      format.html { store_preferred_view }
      format.rss  { render :layout => false }
      format.atom { render :layout => false }
      format.json do
        if params['fl'] == 'id'
          @document_list.map!(&:id)
          @presenter = Blacklight::JsonPresenter.new(@response,
                                                     @document_list,
                                                     facets_from_request,
                                                     blacklight_config)
        else
          @presenter = Blacklight::JsonPresenter.new(@response,
                                                     @document_list,
                                                     facets_from_request,
                                                     blacklight_config)
        end
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

  def get_stats
    data = NewseyeSolrService.get_nb_issues_per_year
    render json: data
  end

  # this method allow you to change url parameters like utf8 or locale
  def search_action_url options = {}
    url_for(options.reverse_merge(action: 'index'))
  end

  def help
    respond_to do |format|
      format.js
    end
  end

  def kw_suggest
    respond_to do |format|
      format.js
    end
  end

  def query_embd_model
    respond_to do |format|
      format.js
    end
  end

  def set_working_dataset
    session[:working_dataset] = params['dataset']['id']
    respond_to do |format|
      format.js {render "set_working_dataset"}
    end
  end

  def confirm_modify_dataset
    current_relevancies = Hash[params['relevancy'].to_unsafe_h.map { |k,v| [k, v.to_i ]}]
    @target_relevancy = params['global_dataset_relevancy'].to_i
    @current_url = params['current_url']
    @relevancy_changes = {added: [], removed: [], modified: [], unchanged:[]}
    current_relevancies.each do |doc_id, doc_relevancy|
        case @target_relevancy
        when 0
          case doc_relevancy
          when 0
            @relevancy_changes[:unchanged] << [doc_id, doc_relevancy]
          when 1, 2, 3
            @relevancy_changes[:removed] << [doc_id, doc_relevancy]
          end
        when 1, 2, 3
          case doc_relevancy
          when 0
            @relevancy_changes[:added] << [doc_id, doc_relevancy]
          when 1, 2, 3
            @relevancy_changes[:unchanged] << [doc_id, doc_relevancy] if doc_relevancy == @target_relevancy
            @relevancy_changes[:modified] << [doc_id, doc_relevancy] if doc_relevancy != @target_relevancy
          end
        end
    end
    @dataset_id = session['working_dataset']
    @dataset_title = Dataset.find(@dataset_id).title
    respond_to do |format|
      format.js
    end
  end

  def apply_modify_dataset
    d = Dataset.find(session['working_dataset'])
    to_add = params['docs'].map do |doc_id|
      {id: doc_id, type: doc_id.include?("_article_") ? "article" : "issue", relevancy: params['target_relevancy'].to_i}
    end
    d.add_docs to_add
    respond_to do |format|
      if d.save
        format.html { redirect_to params[:current_url], notice: 'Dataset was successfully modified.' }
      else
        format.html { redirect_to params[:current_url], notice: 'There was an error modifying the dataset.' }
      end
    end
  end

  def modify_doc_relevancy
    @doc_id = params['doc_id']
    @new_relevancy = params['specific_dataset_relevancy'].to_i
    if params['current_dataset'] # when called from dataset/show
      current_dataset = Dataset.find(params['current_dataset'].to_i)
    else # when called from catalog/index
      current_dataset = Dataset.find(session['working_dataset'])
    end
    @dataset_name = current_dataset.title
    @previous_relevancy = current_dataset.relevancy_for_doc @doc_id
    doc_index = current_dataset.documents.index { |doc| doc['id'] == @doc_id}
    if doc_index.nil?
      if @new_relevancy != 0
        current_dataset.documents << {id: @doc_id, type: @doc_id.include?("_article_") ? "article" : "issue", relevancy: @new_relevancy}
        message = "Added document #{@doc_id} to the dataset #{@dataset_name} (#{helpers.get_relevancy_text @new_relevancy})."
      else
        message = "Nothing was done."
      end
    else
      if @new_relevancy == 0
        current_dataset.documents.delete_at doc_index
        message = "Removed document #{@doc_id} from the dataset #{@dataset_name}."
      else
        current_dataset.documents[doc_index]['relevancy'] = @new_relevancy
        if @previous_relevancy == @new_relevancy
          message = "Nothing was done."
        else
          message = "Relevancy for document #{@doc_id} was set to #{helpers.get_relevancy_text @new_relevancy}."
        end
      end
    end
    respond_to do |format|
      if current_dataset.save
        format.js
        format.html { redirect_to params[:current_url], notice: message }
      else
        format.js
        format.html { redirect_to params[:current_url], notice: 'There was an error updating the dataset.' }
      end
    end
  end

  def article_parts
    render json: Article2.from_solr(params[:article_id]).draw
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
