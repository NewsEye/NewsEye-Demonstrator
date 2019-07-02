module PersonalWorkspaceHelper

  def get_models
    out = {}
    %w(lda dtm pltm hlda pldtm).each do |model_type|
      uri = URI("https://newseye-wp4.cs.helsinki.fi/#{model_type}/list-models")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Get.new(uri.path, {'Content-Type' =>'application/json'})
      res = http.request(req)
      out[model_type] = JSON.parse(res.body)
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

  def api_get_tasks
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/analysis/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri.path, {'Content-Type' =>'application/json', 'Authorization' => "JWT #{generate_token}"})
    res = http.request(req)
    JSON.parse(res.body)
  end

  def api_investigate(query)
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/search/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json', 'Authorization' => "JWT #{generate_token}"})
    req.body = {q: query}.to_json
    res = http.request(req)
    JSON.parse(res.body)
  end

  def api_get_report(task_uuid)
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/report/#{task_uuid}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri.path, {'Authorization' => "JWT #{generate_token}"})
    res = http.request(req)
    JSON.parse(res.body)
  end

  def api_get_results(task_uuid)
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/analysis/#{task_uuid}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri.path, {'Authorization' => "JWT #{generate_token}"})
    res = http.request(req)
    JSON.parse(res.body)
  end

  def api_list_utilities
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/analysis/utilities/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri.path, {'Content-Type' =>'application/json', 'Authorization' => "JWT #{generate_token}"})
    res = http.request(req)
    JSON.parse(res.body)
  end

  def api_analysis_search(search_terms, utility_name, utility_params={})
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/analysis/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json', 'Authorization' => "JWT #{generate_token}"})
    puts "#{utility_name}\n#{search_terms}\n#{utility_params}"
    req.body = {utility: utility_name, target_search: search_terms, utility_parameters: utility_params}.to_json
    res = http.request(req)
    JSON.parse(res.body)
  end

  def api_analysis_task(task_uuid, utility_name, utility_params={})
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/analysis/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json', 'Authorization' => "JWT #{generate_token}"})
    puts "#{utility_name}\n#{task_uuid}\n#{utility_params}"
    req.body = {utility: utility_name, target_uuid: task_uuid, utility_parameters: utility_params}.to_json
    res = http.request(req)
    JSON.parse(res.body)
  end

  def generate_token
    secret = "PHs&xEjS5NaKeNnvMsn1Wvb6pY$384&Id*YOx9LIa6%9GUPKVF4v6FzquxoClcnV6&T!2x4V4E6b$dP3"
    token = {'username' => 'axel.jeancaurant@gmail.com', 'exp' => (Time.now+10.seconds).to_i}
    JWT.encode token, secret, 'HS256', { typ: 'JWT' }
  end

end
