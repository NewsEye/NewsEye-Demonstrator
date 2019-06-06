# -*- encoding : utf-8 -*-

class TopicModelController < ApplicationController
  skip_before_action :verify_authenticity_token

  def investigate
    data = api_investigate params[:query]
    Task.create(user: current_user, status: data['task_status'], uuid: data['uuid'],
                started: data['task_started'], finished: data['task_finished'],
                task_type: data['task_type'], parameters: data['task_parameters'], results: nil)
    respond_to do |format|
      format.js { render file: "personal_workspace/update_tasks", layout: false}
    end
  end

  def list_models
    respond_to do |format|
      format.js { render file: "personal_workspace/update_topic_model_list", layout: false}
    end
  end


  protected

  def get_models
    out = {}
    %w(lda dtm pltm hlda pldtm).each do |model_type|
      uri = URI("https://newseye-wp4.cs.helsinki.fi/#{model_type}/list-models")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Get.new(uri.path, {'Content-Type' =>'application/json'})
      res = http.request(req)
      out[model_type] = JSON.parse(res.body)
    end
  end

end

