# -*- encoding : utf-8 -*-

class InvestigatorController < ApplicationController
  def investigate
    puts '########### Investigate ############'
    post_params = {user: params[:user], solr_query: params[:solr_query]}
    puts post_params.inspect
    x = Net::HTTP.post_form(URI.parse(Rails.configuration.newseye_services['investigator_endpoint']), post_params)
    puts x.body

    head :ok
  end
end