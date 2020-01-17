class PersonalResearchAssistantController < ApplicationController

  def index
    @utilities = PersonalResearchAssistantService.list_utilities
    unless @utilities.empty?
      @user_tasks_uuids = current_user.tasks.select{ |t| t.task_type == 'analysis' }.map do |t|
        input_type = @utilities.select { |u| u['utility_name'] == t.parameters['utility'] }[0]['input_type']
        {uuid: t.uuid, input_type: input_type}
      end
    end
    @topic_models = PersonalResearchAssistantService.get_models
  end

  def list_models
    models = PersonalResearchAssistantService.get_models
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
    utility_opts = params[:utility_params].nil? ? {} : params[:utility_params].to_unsafe_hash
    force_refresh = params[:force_refresh].nil? ? false : true
    if params[:utility] == "query_topic_model"
      model_type, model_name = params[:model_pra_select].split('|')
      utility_opts = {model_type: model_type, model_name: model_name}
    end
    if params[:utility] == 'comparison'
      utility_opts['task_uuids'] = utility_opts['task_uuids'][0].split(',')
      data = PersonalResearchAssistantService.api_analyse(nil, params[:utilities_select], utility_opts)
    end
    if params[:analysis_search_task_submit]
      data = PersonalResearchAssistantService.api_analyse(params[:analysis_search_task_pra_input], params[:utility], utility_opts, force_refresh: force_refresh)
    elsif params[:analysis_dataset_submit]
      dataset_ids = Dataset.find(params[:analysis_dataset_pra_select_pra_input]).get_ids
      query = dataset_ids.map { |id| "id:#{id}" }.join(' OR ')
      data = PersonalResearchAssistantService.api_analyse({q: query}, params[:utility], utility_opts, force_refresh: force_refresh)
    end

    if data['uuid']
      Task.create(user: current_user, status: data['task_status'], uuid: data['uuid'],
                  started: data['task_started'], finished: data['task_finished'],
                  task_type: data['task_type'], parameters: data['task_parameters'], results: data['task_result'])
    else
      puts "Error creating task"
      puts data
    end

    respond_to do |format|
      format.js { render file: "personal_research_assistant/update_tasks", layout: false}
    end
  end

  def investigate_task
    force_refresh = params[:force_refresh].nil? ? false : true
    if params[:investigate_search_task_submit]
      data = PersonalResearchAssistantService.api_investigate(params[:investigate_search_task_pra_input], force_refresh: force_refresh)
    elsif params[:investigate_dataset_submit]
      dataset_ids = Dataset.find(params[:investigate_dataset_pra_input]).get_ids
      query = dataset_ids.map { |id| "id:#{id}" }.join(' OR ')
      data = PersonalResearchAssistantService.api_investigate({q: query}, force_refresh: force_refresh)
    end
    if data['uuid']
      t = Task.create(user: current_user, status: data['task_status'], uuid: data['uuid'],
                  started: data['task_started'], finished: data['task_finished'],
                  task_type: data['task_type'], parameters: data['task_parameters'], results: data['task_result'])
      t.subtasks
    else
      puts "Error creating task"
      puts data
    end
    respond_to do |format|
      format.js { render file: "personal_research_assistant/update_tasks", layout: false}
    end
  end

  def delete_task
    task = Task.where(uuid: params[:uuid]).first
    unless task.nil?
      if task.user == current_user
        task.subtasks.each do |subtask|
          subtask.delete
        end
        task.delete
      end
    end
    respond_to do |format|
      format.js { render file: "personal_research_assistant/update_tasks", layout: false}
    end
  end

  def get_utilities
    render json: PersonalResearchAssistantService.list_utilities
  end

  def get_user_tasks
    if params[:utilities].nil?
      render json: []
    else
      user_tasks_uuids = current_user.tasks.select{ |t| t.task_type == 'analysis' }.map do |t|
        input_type = params[:utilities].select { |u|
          params[:utilities][u]['utility_name'] == t.parameters['utility']
        }
        input_type = input_type.values[0]['input_type']
        {uuid: t.uuid, input_type: input_type}
      end
      render json: user_tasks_uuids
    end
  end

  def get_topic_models
    render json: PersonalResearchAssistantService.get_models
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
        t.subtasks
        t.save unless data.nil?
      end
    end
    respond_to do |format|
      format.js { render file: "personal_research_assistant/update_tasks", layout: false}
    end
  end

  def tm_action
    @topic_number = params[:topic_id]
    tm_type = params[:model_type]
    @model = params[:model_name]
    @topic = PersonalResearchAssistantService.describe_topic(tm_type, @model, @topic_number)
    @wordcloud = PersonalResearchAssistantService.wordcloud_base64(tm_type, @model, @topic_number)
    puts "done"
    respond_to do |format|
      format.html { }
      format.js {render file: 'personal_research_assistant/describe_topics'}
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

  def render_utility
    respond_to do |format|
      format.html { render partial: "personal_research_assistant/utility", locals: {utility: params[:utility], topic_models: params[:topic_models], user_tasks: params[:user_tasks]}}
    end
  end

  def visualize_tm
    respond_to do |format|
      format.html { render html: PersonalResearchAssistantService.visualization("lda", "onb-lda-50").html_safe}
    end
  end

end