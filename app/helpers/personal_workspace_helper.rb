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

end
