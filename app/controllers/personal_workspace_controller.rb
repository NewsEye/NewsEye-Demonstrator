class PersonalWorkspaceController < ApplicationController

  def index
  end

  def list_models
    models = helpers.get_models
    respond_to do |format|
      format.js { render partial: "personal_workspace/update_topic_model_list", locals: models}
    end
  end

  def analysis_task
    if params[:utilities_select] != ''
      issues = Dataset.where(title: params[:dataset_pra_select])[0].issues
      # puts issues
      search_params = {q: "id:(#{issues.join(' ')})"}
      utility_opts = {}
      params.keys.each { |p| utility_opts[p] = params[p] unless %w(dataset_pra_select utilities_select submit controller action).include? p }
      # puts utility_opts
      utility_opts['model_type'] = utility_opts['model_pra_select'].split('-')[-1] if utility_opts['model_pra_select']
      utility_opts['model_name'] = utility_opts.delete 'model_pra_select' if utility_opts['model_pra_select']
      data = helpers.api_analysis_search(search_params, params[:utilities_select], utility_opts)
      # puts data
      if data['uuid']
        Task.create(user: current_user, status: data['task_status'], uuid: data['uuid'],
                    started: data['task_started'], finished: data['task_finished'],
                    task_type: data['task_type'], parameters: data['task_parameters'], results: data['task_results'])
      end
    end
    respond_to do |format|
      format.js { render file: "personal_workspace/update_tasks", layout: false}
    end
  end

  def update_status
    Task.where(user: current_user, task_type: 'analysis').each do |t|
      data = helpers.api_get_results t.uuid
      t.update(status: data['task_status'], uuid: data['uuid'],
               started: data['task_started'], finished: data['task_finished'],
               task_type: data['task_type'], parameters: data['task_parameters'], results: data['task_results'])
      t.save
    end
    Task.where(user:current_user, task_type: 'topic_model_query').each do |t|
      data = helpers.tm_query_results(t.uuid)
      if data['doc_weights']
        t.update(status: 'finished', finished: DateTime.now, results: data)
        t.save
      end
    end
    respond_to do |format|
      format.js { render file: "personal_workspace/update_tasks", layout: false}
    end
  end

  def tm_action
    case params[:submit]
    when "query"
      @model = params[:model_tm_select]
      @dataset = Dataset.where(title: params[:dataset_tm_select])[0].issues
      @model_type = @model.split('-')[-1]
      data = helpers.tm_query(@model_type, @model, @dataset)
      Task.create(user: current_user, status: 'running', uuid: data['task_uuid'],
                  started: DateTime.now, finished: nil,
                  task_type: 'topic_model_query', parameters: {model: @model, dataset: @dataset, model_type: @model_type}, results: nil)
      respond_to do |format|
        format.js { render file: "personal_workspace/update_tasks", layout: false}
      end
    when "describe"
      @topic_number = params[:topic_select]
      tm_type = params[:model_tm_select].split('-')[-1]
      @model = params[:model_tm_select]
      @topic = helpers.describe_topic(tm_type, @model, @topic_number)
      @wordcloud = helpers.wordcloud_base64(tm_type, @model, @topic_number)
      respond_to do |format|
        format.js {render file: 'personal_workspace/describe_topics'}
      end
    end
  end

  def show_report
    @task_uuid = params[:task_uuid]
    @data = helpers.api_get_report(@task_uuid)
    respond_to do |format|
      format.js
    end
  end

  def show_params
    @task_uuid = params[:task_uuid]
    @data = helpers.api_get_results(@task_uuid)
    respond_to do |format|
      format.js
    end
  end

  def tm_show_results
    @task_uuid = params[:task_uuid]
    @results = Task.where(uuid: @task_uuid)[0].results
    respond_to do |format|
      format.js
    end
  end

  def tm_show_params
    @task_uuid = params[:task_uuid]
    @params = Task.where(uuid: @task_uuid)[0].parameters
    respond_to do |format|
      format.js
    end
  end

end