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
    url = "https://newseye-wp5.cs.helsinki.fi/api/report/#{task_uuid}"
    query_api url, nil
  end

  def self.list_utilities
    url = "https://newseye-wp5.cs.helsinki.fi/api/analysis/utilities/"
    query_api url, nil
  end

  def self.api_search(query)
    puts "# # # : #{query.inspect}"
    url = "https://newseye-wp5.cs.helsinki.fi/api/search/"
    case query
    when String
      body = {q: query}
    when Hash
      body = query
    end
    query_api url, body
  end

  def self.api_analyse(data_source, utility_name, utility_params)
    url = "https://newseye-wp5.cs.helsinki.fi/api/analysis/"
    case data_source
    when String
      body = {utility: utility_name, source_uuid: data_source, utility_parameters: utility_params}
      query_api url, body
    when Hash
      body = {utility: utility_name, search_query: data_source, utility_parameters: utility_params}
      query_api url, body
    when nil
      body = {utility: utility_name, utility_parameters: utility_params}
      query_api url, body
    else
      puts "Wrong data soruce used."
      []
    end
  end

  def self.api_investigate(data_source)
    url = "https://newseye-wp5.cs.helsinki.fi/api/investigator/"
    case data_source
    when String
      body = {source_uuid: data_source}
      query_api url, body
    when Hash
      body = {search_query: data_source}
      query_api url, body
    else
      puts "Wrong data source used."
      {}
    end
  end

  ################################################
  # WP4
  ################################################

  def self.get_models
    out = {}
    %w(lda dtm pltm hlda pldtm).each do |model_type|
      url = "https://newseye-wp4.cs.helsinki.fi/#{model_type}/list-models"
      out[model_type] = query_api url, nil, auth: false
    end
    out
  end

  def self.describe_topic(tm_type, model, topic_number)
    url = "https://newseye-wp4.cs.helsinki.fi/#{tm_type}/describe-topic"
    body = {model_name: model, topic_id: "#{topic_number}"}
    out = query_api url, body, auth: false
    out['topic_desc'] unless out.empty?
  end

  def self.wordcloud_base64(tm_type, model, topic_number)
    url = "https://newseye-wp4.cs.helsinki.fi/#{tm_type}/word-cloud"
    body = {model_name: model, topic_id: "#{topic_number}"}
    out = query_api url, body, auth: false, parse: false
    Base64.strict_encode64(out)
  end

  ################################################
  # Common
  ################################################

  def self.query_api(url, body, auth: true, parse: true)
    Rails.logger.info "querying #{url}"
    Rails.logger.info "body is:  #{body.inspect}"
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    headers = {}
    if auth
      headers['Authorization'] = "JWT #{generate_token}"
    end
    if body.nil?
      req = Net::HTTP::Get.new(uri.path, headers)
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
    secret = "PHs&xEjS5NaKeNnvMsn1Wvb6pY$384&Id*YOx9LIa6%9GUPKVF4v6FzquxoClcnV6&T!2x4V4E6b$dP3"
    token = {'username' => 'axel.jeancaurant@gmail.com', 'exp' => (Time.now+10.seconds).to_i}
    JWT.encode token, secret, 'HS256', { typ: 'JWT' }
  end
end