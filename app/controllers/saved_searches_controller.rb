# frozen_string_literal: true
class SavedSearchesController < ApplicationController
  #include Blacklight::SavedSearches
  #
  #helper BlacklightAdvancedSearch::RenderConstraintsOverride
  before_action :set_search, only: [:delete_search]

  def index

  end

  # DELETE /datasets/1
  # DELETE /datasets/1.json
  def delete_search
    @search.destroy
    respond_to do |format|
      format.html { redirect_to '/personal_workspace', notice: 'Search was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def save
    @current_url = params['current_url']
    @search_params = {}
    @search_params[:q] = params[:q]
    @search_params[:fq] = params[:fq]
    @search_params[:qf] = params[:qf]
    @search_params[:rows] = params[:rows]
    @search_params[:sort] = params[:sort]
    @search_params[:defType] = params[:defType]
    puts @search_params
  end

  def confirm_save
    s = Search.new
    s.user_id = current_user.id
    s.description = params[:description]
    s.query = params[:query]
    s.query_url = params[:current_url]
    if params[:describe] == "on"
      # send describe search API call
    end
    respond_to do |format|
      if s.save
        format.html { redirect_to params[:current_url], notice: 'Your search was saved.' }
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
