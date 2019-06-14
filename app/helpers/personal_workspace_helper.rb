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

  def api_get_tasks
    secret = "PHs&xEjS5NaKeNnvMsn1Wvb6pY$384&Id*YOx9LIa6%9GUPKVF4v6FzquxoClcnV6&T!2x4V4E6b$dP3"
    token = {'username' => "axel.jeancaurant@gmail.com", 'exp' => (Time.now+10.seconds).to_i}
    encoded = JWT.encode token, secret, 'HS256', { typ: 'JWT' }
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/analysis/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri.path, {'Content-Type' =>'application/json', 'Authorization' => "JWT #{encoded}"})
    res = http.request(req)
    JSON.parse(res.body)
  end

  def api_investigate(query)
    secret = "PHs&xEjS5NaKeNnvMsn1Wvb6pY$384&Id*YOx9LIa6%9GUPKVF4v6FzquxoClcnV6&T!2x4V4E6b$dP3"
    token = {'username' => "axel.jeancaurant@gmail.com", 'exp' => (Time.now+10.seconds).to_i}
    encoded = JWT.encode token, secret, 'HS256', { typ: 'JWT' }
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/search/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json', 'Authorization' => "JWT #{encoded}"})
    req.body = {q: query}.to_json
    res = http.request(req)
    JSON.parse(res.body)
  end

  def api_get_report(task_uuid)
    secret = "PHs&xEjS5NaKeNnvMsn1Wvb6pY$384&Id*YOx9LIa6%9GUPKVF4v6FzquxoClcnV6&T!2x4V4E6b$dP3"
    token = {'username' => "axel.jeancaurant@gmail.com", 'exp' => (Time.now+10.seconds).to_i}
    encoded = JWT.encode token, secret, 'HS256', { typ: 'JWT' }
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/report/#{task_uuid}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri.path, {'Authorization' => "JWT #{encoded}"})
    res = http.request(req)
    JSON.parse(res.body)
  end

  def api_get_results(task_uuid)
    secret = "PHs&xEjS5NaKeNnvMsn1Wvb6pY$384&Id*YOx9LIa6%9GUPKVF4v6FzquxoClcnV6&T!2x4V4E6b$dP3"
    token = {'username' => "axel.jeancaurant@gmail.com", 'exp' => (Time.now+10.seconds).to_i}
    encoded = JWT.encode token, secret, 'HS256', { typ: 'JWT' }
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/analysis/#{task_uuid}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri.path, {'Authorization' => "JWT #{encoded}"})
    res = http.request(req)
    JSON.parse(res.body)
  end

  def api_list_utilities
    secret = "PHs&xEjS5NaKeNnvMsn1Wvb6pY$384&Id*YOx9LIa6%9GUPKVF4v6FzquxoClcnV6&T!2x4V4E6b$dP3"
    token = {'username' => "axel.jeancaurant@gmail.com", 'exp' => (Time.now+10.seconds).to_i}
    encoded = JWT.encode token, secret, 'HS256', { typ: 'JWT' }
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/analysis/utilities/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri.path, {'Content-Type' =>'application/json', 'Authorization' => "JWT #{encoded}"})
    res = http.request(req)
    JSON.parse(res.body)
  end

  def api_analysis_search(search_terms, utility_name, utility_params={})
    secret = "PHs&xEjS5NaKeNnvMsn1Wvb6pY$384&Id*YOx9LIa6%9GUPKVF4v6FzquxoClcnV6&T!2x4V4E6b$dP3"
    token = {'username' => "axel.jeancaurant@gmail.com", 'exp' => (Time.now+10.seconds).to_i}
    encoded = JWT.encode token, secret, 'HS256', { typ: 'JWT' }
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/analysis/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json', 'Authorization' => "JWT #{encoded}"})
    req.body = {utility: utility_name, target_search: search_terms, utility_parameters: utility_params}.to_json
    res = http.request(req)
    JSON.parse(res.body)
  end

  def api_analysis_task(task_uuid, utility_name, utility_params={})
    secret = "PHs&xEjS5NaKeNnvMsn1Wvb6pY$384&Id*YOx9LIa6%9GUPKVF4v6FzquxoClcnV6&T!2x4V4E6b$dP3"
    token = {'username' => "axel.jeancaurant@gmail.com", 'exp' => (Time.now+10.seconds).to_i}
    encoded = JWT.encode token, secret, 'HS256', { typ: 'JWT' }
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/analysis/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json', 'Authorization' => "JWT #{encoded}"})
    req.body = {utility: utility_name, target_uuid: task_uuid, utility_parameters: utility_params}.to_json
    res = http.request(req)
    JSON.parse(res.body)
  end

end
