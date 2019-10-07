class PersonalResearchAssistantService

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
  ################################################

  def self.query_api(url, body)
    Rails.logger.info "querying #{url}"
    Rails.logger.info "body is:  #{body.inspect}"
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    if body.nil?
      req = Net::HTTP::Get.new(uri.path, {'Authorization' => "JWT #{generate_token}"})
    else
      req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json', 'Authorization' => "JWT #{generate_token}"})
      req.body = body.to_json
    end
    begin
      res = http.request(req)
      return JSON.parse(res.body)
    rescue SocketError => e
      puts "Error connecting to PRA API."
      return []
    end

  end

  def self.generate_token
    secret = "PHs&xEjS5NaKeNnvMsn1Wvb6pY$384&Id*YOx9LIa6%9GUPKVF4v6FzquxoClcnV6&T!2x4V4E6b$dP3"
    token = {'username' => 'axel.jeancaurant@gmail.com', 'exp' => (Time.now+10.seconds).to_i}
    JWT.encode token, secret, 'HS256', { typ: 'JWT' }
  end
end