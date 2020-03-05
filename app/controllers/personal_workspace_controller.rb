class PersonalWorkspaceController < ApplicationController
  def index

  end

  def show
    # TODO check why the task_id is passed when a new search is made from this page
    @task = Task.find params[:task_id]
    @search = @task.search
    @dataset = @task.dataset
  end

  def update_tasks
    Task.where(user: current_user, status: "running", subtask: false).or(Task.where(user: current_user, status: "initializing", subtask: false)).each do |t|
      data = PersonalResearchAssistantService.get_result t.uuid
      t.update(status: data['run_status'], uuid: data['uuid'],
               started: data['run_started'], finished: data['run_finished'],
               task_type: t.task_type, parameters: data['user_parameters'],
               results: data['result']) unless data.nil?
      t.subtasks
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

  end

  def get_task_report

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

end