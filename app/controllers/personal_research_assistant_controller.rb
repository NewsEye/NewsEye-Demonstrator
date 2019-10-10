class PersonalResearchAssistantController < ApplicationController

  def index
  end

  def list_models
    models = helpers.get_models
    respond_to do |format|
      format.js { render partial: "personal_research_assistant/update_topic_model_list", locals: models}
    end
  end

  def search_task
    data = PersonalResearchAssistantService.api_search(params[:query_pra_input])
    if data['uuid']
      Task.create(user: current_user, status: data['task_status'], uuid: data['uuid'],
                  started: data['task_started'], finished: data['task_finished'],
                  task_type: data['task_type'], parameters: data['task_parameters'], results: data['task_result'])
    else
      puts data
    end
    respond_to do |format|
      format.js { render file: "personal_research_assistant/update_tasks", layout: false}
    end
  end

  def create_search_task

    data = PersonalResearchAssistantService.api_search(params.except('authenticity_token', 'controller', 'action').to_unsafe_h)
    if data['uuid']
      Task.create(user: current_user, status: data['task_status'], uuid: data['uuid'],
                  started: data['task_started'], finished: data['task_finished'],
                  task_type: data['task_type'], parameters: data['task_parameters'], results: data['task_result'])
      message = "Search task was successfully created."
      status = 'success'
    else
      puts data
      message = "A problem occured while creating the search task."
      status = 'warning'
    end
    respond_to do |format|
      format.js { render partial: "catalog/confirm_add_search", locals: {message: message, status: status}}
    end
  end

  def analysis_task
    # if params[:utilities_select] != ''
    #   if params['analyse_query_pra_input'] != ''
    #     search_params = {q: params['analyse_query_pra_input']}
    #   else
    #     issues = Dataset.where(title: params[:analyse_dataset_pra_select])[0].issues
    #     search_params = {q: "id:(#{issues.join(' ')})"}
    #   end
    #   utility_opts = {}
    #   params.keys.each { |p| utility_opts[p] = params[p] unless %w(analyse_query_pra_input find_steps_from_time_series_task_input analyse_dataset_pra_select utilities_select submit controller action).include? p }
    #   # puts utility_opts
    #   utility_opts['model_type'] = utility_opts['model_pra_select'].split('-')[-1] if utility_opts['model_pra_select']
    #   utility_opts['model_name'] = utility_opts.delete 'model_pra_select' if utility_opts['model_pra_select']
    #
    #   if params[:utilities_select] == 'find_steps_from_time_series'
    #     # data = helpers.api_analysis_task(params['find_steps_from_time_series_task_input'], params[:utilities_select], utility_opts)
    #     data = helpers.api_analysis_search(search_params, params[:utilities_select], {})
    #   else
    #     data = helpers.api_analysis_search(search_params, params[:utilities_select], utility_opts)
    #   end
    #   # puts data
    #   if data['uuid']
    #     Task.create(user: current_user, status: data['task_status'], uuid: data['uuid'],
    #                 started: data['task_started'], finished: data['task_finished'],
    #                 task_type: data['task_type'], parameters: data['task_parameters'], results: data['task_results'])
    #   else
    #     puts data
    #   end
    # end
    utility_opts = params[:utility_params].nil? ? {} : params[:utility_params].to_unsafe_hash

    case params[:source_select]
    when 'query'
      data = PersonalResearchAssistantService.api_analyse({q: params[:analysis_query_pra_input]}, params[:utilities_select], utility_opts)
    when 'search_task'
      data = PersonalResearchAssistantService.api_analyse(params[:analysis_search_task_pra_input], params[:utilities_select], utility_opts)
    when 'dataset'
      dataset_ids = Dataset.find(params[:analysis_dataset_pra_select_pra_input]).get_ids
      query = dataset_ids.map { |id| "id:#{id}" }.join(' OR ')
      data = PersonalResearchAssistantService.api_analyse({q: query}, params[:utilities_select], utility_opts)
    end
    if data['uuid']
      Task.create(user: current_user, status: data['task_status'], uuid: data['uuid'],
                  started: data['task_started'], finished: data['task_finished'],
                  task_type: data['task_type'], parameters: data['task_parameters'], results: data['task_result'])
    else
      puts data
    end

    respond_to do |format|
      format.js { render file: "personal_research_assistant/update_tasks", layout: false}
    end
  end

  def investigate_task
    case params[:source_select]
    when 'search_task'
      data = PersonalResearchAssistantService.api_investigate(params[:investigate_search_task_pra_input])
    when 'dataset'
      dataset_ids = Dataset.find(params[:investigate_dataset_pra_select_pra_input]).get_ids
      query = dataset_ids.map { |id| "id:#{id}" }.join(' OR ')
      data = PersonalResearchAssistantService.api_investigate({q: query})
    end
    if data['uuid']
      Task.create(user: current_user, status: data['task_status'], uuid: data['uuid'],
                  started: data['task_started'], finished: data['task_finished'],
                  task_type: data['task_type'], parameters: data['task_parameters'], results: data['task_result'])
    else
      puts data
    end
    respond_to do |format|
      format.js { render file: "personal_research_assistant/update_tasks", layout: false}
    end
  end

  def update_status
    Task.where(user: current_user, status: "running").each do |t|
      if t.task_type == "topic_model_query"
        data = helpers.tm_query_results(t.uuid)
        if data['doc_weights']
          t.update(status: 'finished', finished: DateTime.now, results: data)
          t.save
        end
      else
        case t.task_type
        when 'search'
          data = PersonalResearchAssistantService.get_search_task t.uuid
        when 'analysis'
          data = PersonalResearchAssistantService.get_analysis_task t.uuid
          puts data
        when 'investigator'
          data = PersonalResearchAssistantService.get_investigate_task t.uuid
        else
          data = nil
        end
        t.update(status: data['task_status'], uuid: data['uuid'],
                 started: data['task_started'], finished: data['task_finished'],
                 task_type: data['task_type'], parameters: data['task_parameters'],
                 results: data['task_result']) unless data.nil?
        t.save unless data.nil?
      end
    end
    respond_to do |format|
      format.js { render file: "personal_research_assistant/update_tasks", layout: false}
    end
  end

  def tm_action
    case params[:submit]
    when "query"
      @model = params[:model_tm_select]
      d = Dataset.where(title: params[:dataset_tm_select])[0]
      @dataset = d.issues
      @model_type = @model.split('-')[-1]
      data = helpers.tm_query(@model_type, @model, @dataset)
      Task.create(user: current_user, status: 'running', uuid: data['task_uuid'],
                  started: DateTime.now, finished: nil,
                  task_type: 'topic_model_query', parameters: {model: @model, dataset: @dataset, model_type: @model_type}, results: nil)
      respond_to do |format|
        format.js { render file: "personal_research_assistant/update_tasks", layout: false}
      end
    when "describe"
      @topic_number = params[:topic_select]
      tm_type = params[:model_tm_select].split('-')[-1]
      @model = params[:model_tm_select]
      @topic = helpers.describe_topic(tm_type, @model, @topic_number)
      @wordcloud = helpers.wordcloud_base64(tm_type, @model, @topic_number)
      respond_to do |format|
        format.js {render file: 'personal_research_assistant/describe_topics'}
      end
    end
  end

  def show_report
    @task_uuid = params[:task_uuid]
    @data = PersonalResearchAssistantService.get_report(@task_uuid)
    respond_to do |format|
      format.js
    end
  end

  def show_results
    @task_uuid = params[:task_uuid]
    @data = Task.where(uuid: @task_uuid).first.results
    respond_to do |format|
      format.js
    end
  end

  def show_params
    @task_uuid = params[:task_uuid]
    @data = Task.where(uuid: @task_uuid).first.parameters
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