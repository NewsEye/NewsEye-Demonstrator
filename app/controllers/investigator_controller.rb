# -*- encoding : utf-8 -*-

class InvestigatorController < ApplicationController
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

  def update_status
    current_user.tasks.where(status: 'running').each do |t|
      data = api_update_status t.uuid
      t.update(status: data['task_status'], finished: data['task_finished'], results: data['results'])
    end
    respond_to do |format|
      format.js { render file: "personal_workspace/update_tasks", layout: false}
    end
  end

  def get_report
    data = api_get_report params[:task_uuid]
  end

  def allowed_params
    params.permit
  end
end

