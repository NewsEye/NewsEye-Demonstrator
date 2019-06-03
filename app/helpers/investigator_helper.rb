module InvestigatorHelper

  def api_investigate query
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

  def api_update_status task_uuid
    secret = "PHs&xEjS5NaKeNnvMsn1Wvb6pY$384&Id*YOx9LIa6%9GUPKVF4v6FzquxoClcnV6&T!2x4V4E6b$dP3"
    token = {'username' => "axel.jeancaurant@gmail.com", 'exp' => (Time.now+10.seconds).to_i}
    encoded = JWT.encode token, secret, 'HS256', { typ: 'JWT' }
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/search/#{task_uuid}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri.path, {'Content-Type' =>'application/json', 'Authorization' => "JWT #{encoded}"})
    res = http.request(req)
    JSON.parse(res.body)
  end

  def api_get_report task_uuid
    secret = "PHs&xEjS5NaKeNnvMsn1Wvb6pY$384&Id*YOx9LIa6%9GUPKVF4v6FzquxoClcnV6&T!2x4V4E6b$dP3"
    token = {'username' => "axel.jeancaurant@gmail.com", 'exp' => (Time.now+10.seconds).to_i}
    encoded = JWT.encode token, secret, 'HS256', { typ: 'JWT' }
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/report/#{task_uuid}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri.path, {'Content-Type' =>'application/json', 'Authorization' => "JWT #{encoded}"})
    res = http.request(req)
    JSON.parse(res.body)
  end
end
