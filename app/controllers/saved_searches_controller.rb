# frozen_string_literal: true
class SavedSearchesController < ApplicationController
  #include Blacklight::SavedSearches
  #
  #helper BlacklightAdvancedSearch::RenderConstraintsOverride
  before_action :set_search, only: [:delete_search, :get_ids]

  def index

  end

  def get_ids
    search_params = Rack::Utils.parse_nested_query @search.query_url[@search.query_url.index("/catalog?")+9..-1]
    search_params = Blacklight::Solr::Request.new search_params
    sb = SearchBuilder.new self
    sb = sb.with search_params
    sb = sb.except :add_facetting_to_solr, :add_paging_to_solr, :add_facet_paging_to_solr, :add_solr_fields_to_query, :add_highlight
    sb = sb.append :only_ids, :add_access_controls_to_solr_params
    puts sb.processor_chain
    sb.processor_chain.each do |method| sb.send(method, search_params) end
    pp "#######"
    pp search_params
    pp "#######"
    solr = Blacklight::Solr::Repository.new CatalogController.blacklight_config
    resp = solr.search(sb)
    render json: resp
  end

  # DELETE /datasets/1
  # DELETE /datasets/1.json
  def delete_search
    Task.where(search: @search).map(&:destroy)
    @search.destroy
    respond_to do |format|
      format.html { redirect_to '/personal_workspace', notice: 'Search was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def save
    @current_url = params['current_url']
    search_params = Rack::Utils.parse_nested_query @current_url[@current_url.index("/catalog?")+9..-1]
    search_params = Blacklight::Solr::Request.new search_params
    sb = SearchBuilder.new self
    sb = sb.with search_params
    sb = sb.except :add_facetting_to_solr, :add_paging_to_solr, :add_facet_paging_to_solr, :add_solr_fields_to_query, :add_highlight, :add_access_controls_to_solr_params
    sb.processor_chain.each do |method| puts method; sb.send(method, search_params) end
    @search_params = sb.to_h
    #
    # @search_params = {}
    # @search_params[:q] = params[:q]
    # @search_params[:fq] = params[:fq]
    # @search_params[:qf] = params[:qf]
    # @search_params[:rows] = params[:rows]
    # @search_params[:sort] = params[:sort]
    # @search_params[:defType] = params[:defType]
    # puts @search_params
  end

  def confirm_save
    s = Search.new
    s.user_id = current_user.id
    s.description = params[:description]
    s.query = params[:query]
    s.query_url = params[:current_url]
    respond_to do |format|
      if s.save
        if params[:describe] == "on"
          # send describe search API call
          data = PersonalResearchAssistantService.describe_search JSON.parse(s.query)
          puts data
          if data['uuid']
            Task.create(user: current_user, status: data['run_status'], uuid: data['uuid'],
                        started: data['run_started'], finished: data['run_finished'], search: s,
                        task_type: "describe_search", parameters: data['solr_query'], results: data['task_result'])
            describe_notice = "and a description task was created"
          else
            puts data
          end
        end
        notice = "Your search was saved"
        notice = "#{notice} #{describe_notice}" unless describe_notice.nil?
        notice = "#{notice}."
        format.html { redirect_to params[:current_url], notice: notice }
      else
        format.html { redirect_to params[:current_url], notice: 'There was an error saving the search.' }
      end
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_search
    @search = Search.find(params[:id])
  end
end
