module PersonalWorkspaceHelper

  def doc_linking(doc_ids)
    uri = URI("https://newseye-wp4.cs.helsinki.fi/doc-linking")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json'})
    req.body = {documents: doc_ids}.to_json
    res = http.request(req)
    JSON.parse(res.body)
  end

  def get_processor_name(task, subtask)
    # st = task.results['result'].select{|st| st['uuid'] == subtask.uuid}[0]
    st = task.results.select{|st| st['uuid'] == subtask.uuid}[0]
    st['processor'] unless st.nil?
  end

  def tm_query(model_type, model, doc_ids)
    uri = URI("https://newseye-wp4.cs.helsinki.fi/#{model_type}/query")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json'})
    req.body = {model_name: model, documents: doc_ids}.to_json
    res = http.request(req)
    JSON.parse(res.body)
  end

  def tm_query_results(uuid)
    uri = URI("https://newseye-wp4.cs.helsinki.fi/query-results")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json'})
    req.body = {task_uuid: uuid}.to_json
    res = http.request(req)
    JSON.parse(res.body)
  end

end
