class PersonalWorkspaceController < ApplicationController

  def index
  end

  def show_report
    @task_uuid = params[:task_uuid]
    respond_to do |format|
      format.html
      format.js
    end
  end

  def show_params
    @task_uuid = params[:task_uuid]
    respond_to do |format|
      format.html
      format.js
    end
  end

end