# -*- encoding : utf-8 -*-

class InvestigatorController < ApplicationController
  skip_before_action :verify_authenticity_token
  def investigate
    data = helpers.api_investigate params[:query]
    # Task.create(user: current_user, status: data['task_status'], uuid: data['uuid'],
    #              started: data['task_started'], finished: data['task_finished'],
    #              task_type: data['task_type'], parameters: data['task_parameters'], results: data['task_results'])
    respond_to do |format|
      format.js { render file: "personal_workspace/update_tasks", layout: false}
    end
  end

  def update_status
    respond_to do |format|
      format.js { render file: "personal_workspace/update_tasks", layout: false}
    end
  end

end

