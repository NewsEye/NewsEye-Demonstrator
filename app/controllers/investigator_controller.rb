# -*- encoding : utf-8 -*-

class InvestigatorController < ApplicationController
  skip_before_action :verify_authenticity_token
  def investigate
    puts '########### Investigate ############'
    # post_params = {user: params[:user], solr_query: params[:solr_query]}
    # puts post_params.inspect
    # x = Net::HTTP.post_form(URI.parse(Rails.configuration.newseye_services['investigator_endpoint']), post_params)
    # puts x.body
    #
    # head :ok

    secret = "PHs&xEjS5NaKeNnvMsn1Wvb6pY$384&Id*YOx9LIa6%9GUPKVF4v6FzquxoClcnV6&T!2x4V4E6b$dP3"
    token = {'username' => "axel.jeancaurant@gmail.com", 'exp' => (Time.now+10.seconds).to_i}
    encoded = JWT.encode token, secret, 'HS256', { typ: 'JWT' }
    uri = URI("https://newseye-wp5.cs.helsinki.fi/api/search/")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    # req = Net::HTTP::Get.new(uri.path, {'Content-Type' =>'application/json', 'Authorization' => "JWT #{encoded}"})
    req = Net::HTTP::Get.new(uri.path + "4162b33e-3f9e-4359-b312-b6c47546ca76", {'Content-Type' =>'application/json', 'Authorization' => "JWT #{encoded}"})
    # req = Net::HTTP::Post.new(uri.path, {'Content-Type' =>'application/json', 'Authorization' => "JWT #{encoded}"})
    # req.body = {"q" => "test"}.to_json
    res = http.request(req)
    puts "response #{res.body}"
    puts JSON.parse(res.body)
    return
  end
end

