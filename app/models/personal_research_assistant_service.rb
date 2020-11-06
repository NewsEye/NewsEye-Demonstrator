class PersonalResearchAssistantService

  ################################################
  # WP5
  ################################################

  def self.get_search_task(task_uuid)
    url = "https://newseye-wp5.cs.helsinki.fi/api/search/#{task_uuid}"
    query_api url, nil
  end

  def self.get_analysis_task(task_uuid)
    url = "https://newseye-wp5.cs.helsinki.fi/api/analysis/#{task_uuid}"
    query_api url, nil
  end

  def self.get_investigate_task(task_uuid)
    url = "https://newseye-wp5.cs.helsinki.fi/api/investigator/#{task_uuid}"
    query_api url, nil
  end

  def self.get_report(task_uuid)
      url = "https://newseye-wp5.cs.helsinki.fi/api/report#{task_uuid}"
      query_api url, nil
  end

  def self.get_experiment_report(task_uuid)
      url = "https://newseye-wp5.cs.helsinki.fi/api/report/report?run=#{task_uuid}"
      query_api url, nil
  end

  def self.list_utilities
      url = "https://newseye-wp5.cs.helsinki.fi/api/analysis/processors/"
      res = query_api url, nil, true, false
      return res.nil? ? [] : res
  end

  def self.explain(task_uuid)
      url = "https://newseye-wp5.cs.helsinki.fi/api/explainer/explain?run=#{task_uuid}"
      res = query_api url, nil, true, false
      return res.nil? ? [] : res
  end

  def self.api_search(query)
    puts "# # # : #{query.inspect}"
    url = "https://newseye-wp5.cs.helsinki.fi/api/search/"
    case query
    when String
      body = {q: query}
    when Hash
      query.except! *(query.keys.select{|k| !k.to_s.index('.facet.limit').nil? })
      body = query
    end
    query_api url, body
  end

  def self.api_analyse(data_source, utility_name, utility_params, force_refresh: false)
    url = "https://newseye-wp5.cs.helsinki.fi/api/analysis/"
    case data_source
    when String
      body = {utility: utility_name, source_uuid: data_source, utility_parameters: utility_params, force_refresh: force_refresh}
      query_api url, body
    when Hash
      body = {utility: utility_name, search_query: data_source, utility_parameters: utility_params, force_refresh: force_refresh}
      query_api url, body
    when nil || self.cy.nodes(":selected").data("type")
      body = {utility: utility_name, utility_parameters: utility_params, force_refresh: force_refresh}
      query_api url, body
    else
      puts "Wrong data soruce used."
      []
    end
  end

  def self.api_investigate(data_source, force_refresh: false)
    url = "https://newseye-wp5.cs.helsinki.fi/api/investigator/"
    case data_source
    when String
      body = {source_uuid: data_source, force_refresh: force_refresh}
      query_api url, body
    when Hash
      body = {search_query: data_source, force_refresh: force_refresh}
      query_api url, body
    else
      puts "Wrong data source used."
      {}
    end
  end

  ################################################

  def self.describe_search(query)
    url = "https://newseye-wp5.cs.helsinki.fi/api/investigator/"
    body = {search_query: query, parameters: {describe: "T"}}
    query_api url, body
  end

  def self.investigate_search(query)
    url = "https://newseye-wp5.cs.helsinki.fi/api/investigator/"
    body = {search_query: query}
    query_api url, body
  end

  def self.describe_dataset(dataset_title, username)
    url = "https://newseye-wp5.cs.helsinki.fi/api/investigator/"
    body = {dataset: {name: dataset_title, user: username}, parameters: {describe: "T"}}
    query_api url, body
  end

  def self.investigate_dataset(dataset_title, username)
    url = "https://newseye-wp5.cs.helsinki.fi/api/investigator/"
    body = {dataset: {name: dataset_title, user: username}, force_refresh: true}
    query_api url, body
  end

  def self.run_tool(dataset_title, username, tool_name, tool_parameters)
      url = "https://newseye-wp5.cs.helsinki.fi/api/analysis/"
      body = {dataset: {name: dataset_title, user: username}, processor: tool_name, parameters: tool_parameters, force_refresh: true}
      query_api url, body
  end

  def self.get_result(run_uuid)
    url = "https://newseye-wp5.cs.helsinki.fi/api/investigator/result?run=#{run_uuid}"
    query_api url, nil
  end

  def self.get_task_result(task_uuid)
    url = "https://newseye-wp5.cs.helsinki.fi/api/investigator/result?task=#{task_uuid}"
    query_api url, nil
  end

  def self.get_run_report(task_uuid)
    url = "https://newseye-wp5.cs.helsinki.fi/api/report/report?run=#{task_uuid}&nolinks=true"
    query_api url, nil, true, false
  end

  def self.get_task_report(task_uuid)
    url = "https://newseye-wp5.cs.helsinki.fi/api/report/report?task=#{task_uuid}&nolinks=true"
    query_api url, nil, true, false
  end

  ################################################
  # WP4
  ################################################

  def self.get_models
    out = {}
    # %w(lda dtm pltm hlda pldtm).each do |model_type|
    %w(lda dtm pltm pldtm).each do |model_type|
      url = "https://newseye-wp4.cs.helsinki.fi/#{model_type}/list-models"
      out[model_type] = query_api url, nil, false
    end
    return out.nil? ? [] : out
  end

  def self.describe_topic(tm_type, model, topic_number, time_slice=nil)
    url = "https://newseye-wp4.cs.helsinki.fi/#{tm_type}/describe-topic"
    body = {model_name: model, topic_id: "#{topic_number}"}
    body[:time_slice] = time_slice unless time_slice.nil?
    out = query_api url, body, false
    out['topic_desc'] unless out.empty?
  end

  def self.wordcloud_base64(tm_type, model, topic_number, time_slice=nil)
    url = "https://newseye-wp4.cs.helsinki.fi/#{tm_type}/word-cloud"
    body = {model_name: model, topic_id: "#{topic_number}"}
    body[:time_slice] = time_slice unless time_slice.nil?
    out = query_api url, body, false, false
    Base64.strict_encode64(out)
  end

  def self.get_valid_years(model_name)
    url = "https://newseye-wp4.cs.helsinki.fi/dtm/valid-years"
    body = {model_name: model_name}
    out = query_api url, body, false
  end

  def self.visualization(model_type, model_name)
    url = "https://newseye-wp4.cs.helsinki.fi/#{model_type}/pyldavis"
    body = {model_name: model_name}
    out = query_api url, body, false, false
  end

  def self.visualization_dtm(model_name)
    url = "https://newseye-wp4.cs.helsinki.fi/dtm/bar_chart"
    body = {model_name: model_name}
    out = query_api url, body, false, false
  end

  def self.tm_query(model_type, model_name, doc_ids)
    url = "https://newseye-wp4.cs.helsinki.fi/#{model_type}/query"
    body = {model_name: model_name, documents: doc_ids}
    out = query_api url, body, false, true
  end

  def self.tm_query_results(task_uuid)
    url = "https://newseye-wp4.cs.helsinki.fi/query-results"
    body = {task_uuid: task_uuid}
    out = query_api url, body, false, true
  end

  def self.tm_doc_linking_results(task_uuid)
    url = "https://newseye-wp4.cs.helsinki.fi/doc-linking-results"
    body = {task_uuid: task_uuid}
    out = query_api url, body, false, true
  end

  def self.doc_linking(model_type, model_name, num_docs, doc_ids)
    url = "https://newseye-wp4.cs.helsinki.fi/lda-doc-linking"
    body = {model_name: model_name, num_docs: num_docs, documents: doc_ids}
    out = query_api url, body, false, true
  end

  def self.word_embeddings_query(word, language, num_words)
    url = "https://newseye-wp4.cs.helsinki.fi/word-embeddings/query"
    body = {word: word, lang: language, num_words: num_words}
    out = query_api url, body, false
  end

  ################################################
  # Common
  ################################################

  def self.query_api(url, body, auth=true, parse=true)
    Rails.logger.info "querying #{url}"
    Rails.logger.info "body is:  #{body.to_json}"
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    headers = {}
    if auth
      headers['Authorization'] = "JWT #{generate_token}"
    end
    if body.nil?
      req = Net::HTTP::Get.new(url, headers)
    else
      headers["Content-Type"] = 'application/json'
      req = Net::HTTP::Post.new(uri.path, headers)
      req.body = body.to_json
    end
    Rails.logger.info "headers are:  #{headers.inspect}"
    begin
      res = http.request(req)
      # Rails.logger.info "response:  #{res.body}"
      return res.body unless parse
      return JSON.parse(res.body)
    rescue SocketError => e
      puts "Error connecting to PRA API."
      return nil
    end
  end

  def self.generate_token
    secret = ENV["WP3_SECRET"]
    # token = {'username' => 'axel.jeancaurant@gmail.com', 'exp' => (Time.now+10.seconds).to_i}
    token = {'username' => 'axel.jeancaurant@gmail.com', 'exp' => (Time.now+2.days).to_i}
    JWT.encode token, secret, 'HS256', { typ: 'JWT' }
  end
end