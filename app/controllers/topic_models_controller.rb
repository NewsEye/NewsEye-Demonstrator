class TopicModelsController < ApplicationController

  def index
    @models = PersonalResearchAssistantService.get_models
  end

  def describe_tm_modal
    @model_name = params[:model_name]
    @model_type = params[:model_type]
  end

  def visualize_lda_modal
    @model_name = params[:tm_name]
    if @model_name.index("dtm").nil?
      @data = PersonalResearchAssistantService.visualization("lda", @model_name)
    else
      # @data = File.read(File.join(Rails.root, "public", "dtm-visualization", "#{@model_name}.html"))
      render file: "public/dtm-visualization/#{@model_name}.html", layout: false
    end
  end

  def describe
    text_description = PersonalResearchAssistantService.describe_topic params[:model_type], params[:model_name], params[:topic_number], params[:year]
    wordcloud = PersonalResearchAssistantService.wordcloud_base64 params[:model_type], params[:model_name], params[:topic_number], params[:year]
    render json: {text_description: text_description, wordcloud: wordcloud}
  end

  def query_modal
    @dataset = Dataset.find params[:dataset_id]
    @models = PersonalResearchAssistantService.get_models
  end

  def query
    dataset = Dataset.find params[:dataset_id]
    doc_ids = dataset.documents.map{ |doc| doc['id']}
    model_type, model_name = params[:model_tm_select].split(";;")
    if params[:query_type] == "query"
      data = PersonalResearchAssistantService.tm_query model_type, model_name, doc_ids
      puts data
      if data['task_uuid']
        Task.create(user: current_user, status: "running", uuid: data['task_uuid'],
                    started: Time.now, task_type: "tm_query", dataset: dataset,
                    parameters: {model_type: model_type, model_name: model_name, documents: doc_ids, dataset_title: dataset.title})
        respond_to do |format|
          format.html { redirect_to '/personal_workspace', notice: 'Topic modelling query task was successfully created.' }
        end
      else
        puts data
      end
    elsif params[:query_type] == "doc-linking"
      num_docs = params[:num_docs].to_i
      data = PersonalResearchAssistantService.doc_linking model_type, model_name, num_docs, doc_ids
      puts data
      if data['task_uuid']
        Task.create(user: current_user, status: "running", uuid: data['task_uuid'],
                    started: Time.now, task_type: "tm_doc_linking", dataset: dataset,
                    parameters: {model_type: model_type, model_name: model_name, documents: doc_ids, dataset_title: dataset.title})
        respond_to do |format|
          format.html { redirect_to '/personal_workspace', notice: 'Topic modelling query task was successfully created.' }
        end
      else
        puts data
      end
    end
  end

  def doc_linking

  end

  def query_results
    task = Task.where(uuid: params[:task_uuid])[0]
    data = task.results
    data['uuid'] = params[:task_uuid]
    render json: data
  end

end

