class PersonalWorkspaceController < ApplicationController
  def index

  end

  def show
    # TODO check why the task_id is passed when a new search is made from this page
    @task = Task.find params[:task_id]
    @search = @task.search
    @dataset = @task.dataset
    puts @task.task_type
    if @task.task_type == "tm_doc_linking"
      ids = @task.results['similar_docs']
      puts ids
      @documents_list = NewseyeSolrService.query({q: "*:*", fq: "id:(#{ids.join(' ')})", rows: 9999})
      puts @documents_list
    end
  end

  def update_tasks
    Task.where(user: current_user, status: "running", subtask: false).or(Task.where(user: current_user, status: "initializing", subtask: false)).each do |t|
      case t.task_type
      when "describe_search", "describe_dataset"
        data = PersonalResearchAssistantService.get_result t.uuid
        t.update(status: data['run_status'], uuid: data['uuid'],
                 started: data['run_started'], finished: data['run_finished'],
                 task_type: t.task_type, parameters: data['user_parameters'],
                 results: data['result']) unless data.nil?
        t.subtasks
      when "tm_query"
        data = PersonalResearchAssistantService.tm_query_results t.uuid
        puts data
        if data.instance_of? Hash
          t.update(status: "finished", finished: Time.now, results: data)
        end
      when "tm_doc_linking"
        data = PersonalResearchAssistantService.tm_doc_linking_results t.uuid
        puts data
        if data.instance_of? Hash
          t.update(status: "finished", finished: Time.now, results: data)
        end
      end
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
      format.js { render file: "personal_workspace/update_tasks", layout: false}
    end
  end

  def describe_search
    search = Search.find(params[:search_id])
    data = PersonalResearchAssistantService.describe_search JSON.parse(search.query)
    puts data
    if data['uuid']
      Task.create(user: current_user, status: data['run_status'], uuid: data['uuid'],
                  started: data['run_started'], finished: data['run_finished'], search: search,
                  task_type: "describe_search", parameters: data['solr_query'], results: data['task_result'])
    else
      puts data
    end
    respond_to do |format|
      format.js { render file: "personal_workspace/update_tasks", layout: false}
    end
  end

  def describe_dataset
    dataset = Dataset.find(params[:dataset_id])
    username = User.find(dataset.user_id).email
    data = PersonalResearchAssistantService.describe_dataset dataset.title, username
    puts data
    if data['uuid']
      Task.create(user: current_user, status: data['run_status'], uuid: data['uuid'],
                  started: data['run_started'], finished: data['run_finished'], dataset: dataset,
                  task_type: "describe_dataset", parameters: data['solr_query'], results: data['task_result'])
    else
      puts data
    end
    respond_to do |format|
      format.js { render file: "personal_workspace/update_tasks", layout: false}
    end
  end

  def describe_search_modal
    @results = PersonalResearchAssistantService.get_result params[:run_uuid]

    respond_to do |format|
      format.js
    end
  end

  def get_run_report
    data = PersonalResearchAssistantService.get_run_report params[:run_uuid]
    render json: data
  end

  def get_task_report
    data = PersonalResearchAssistantService.get_task_report params[:task_uuid]
    data = JSON.parse data
    data['task_uuid'] = params[:task_uuid]
    render json: data
  end

  def get_task_results
    parent_task = Task.where(uuid: params[:parent_task_uuid])[0]
    task = Task.where(uuid: params[:task_uuid])[0]
    st = parent_task.results.select{|st| st['uuid'] == task.uuid}[0]
    processor_name = st['processor']
    data = task.results
    data['uuid'] = params[:task_uuid]
    data['processor_name'] = processor_name
    render json: data
  end

  def flowy

  end

end