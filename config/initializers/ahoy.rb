class Ahoy::Store < Ahoy::DatabaseStore
  def authenticate(data)
    # disables automatic linking of visits and users
  end
end

# GDPR compliance
Ahoy.mask_ips = true
Ahoy.cookies = false

# set to true for JavaScript tracking
Ahoy.api = false

# better user agent parsing
Ahoy.user_agent_parser = :device_detector

Ahoy.visit_duration = 30.minutes