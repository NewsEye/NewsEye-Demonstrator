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
    search_params = {q: params[:target_search]}
    data = helpers.api_analysis_search(search_params, params[:utilities_select])
    # Task.create(user: current_user, status: data['task_status'], uuid: data['uuid'],
    #             started: data['task_started'], finished: data['task_finished'],
    #             task_type: data['task_type'], parameters: data['task_parameters'], results: data['task_results'])
    respond_to do |format|
      format.js { render file: "personal_workspace/update_tasks", layout: false}
    end
  end

  def tm_action
    case params[:submit]
    when "list"

    when "describe"
      @topic_number = params[:topic_select]
      tm_type = params[:model_tm_select].split('-')[-1]
      @model = params[:model_tm_select]

      uri = URI("https://newseye-wp4.cs.helsinki.fi/#{tm_type}/describe-topic")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json'})
      req.body = {model_name: @model, topic_id: "#{@topic_number}"}.to_json
      res = http.request(req)
      puts res.body
      @topic = JSON.parse(res.body)['topic_desc']

      uri = URI("https://newseye-wp4.cs.helsinki.fi/#{tm_type}/word-cloud")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json'})
      req.body = {model_name: @model, topic_id: "#{@topic_number}"}.to_json
      res = http.request(req)
      @wordcloud = Base64.strict_encode64(res.body)

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

end