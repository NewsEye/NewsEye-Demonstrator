module PersonalWorkspaceHelper

  def get_models
    out = {}
    %w(lda dtm pltm hlda pldtm).each do |model_type|
      uri = URI("https://newseye-wp4.cs.helsinki.fi/#{model_type}/list-models")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Get.new(uri.path, {'Content-Type' =>'application/json'})
      begin
        res = http.request(req)
        out[model_type] = JSON.parse(res.body)
      rescue SocketError => e
        out[model_type] = []
      end
    end
    out
  end

  def describe_topic(tm_type, model, topic_number)
    uri = URI("https://newseye-wp4.cs.helsinki.fi/#{tm_type}/describe-topic")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json'})
    req.body = {model_name: model, topic_id: "#{topic_number}"}.to_json
    res = http.request(req)
    JSON.parse(res.body)['topic_desc']
  end

  def wordcloud_base64(tm_type, model, topic_number)
    uri = URI("https://newseye-wp4.cs.helsinki.fi/#{tm_type}/word-cloud")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json'})
    req.body = {model_name: model, topic_id: "#{topic_number}"}.to_json
    res = http.request(req)
    Base64.strict_encode64(res.body)
  end

  def doc_linking(doc_ids)
    uri = URI("https://newseye-wp4.cs.helsinki.fi/doc-linking")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json'})
    req.body = {documents: doc_ids}.to_json
    res = http.request(req)
    JSON.parse(res.body)
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
