class StanceEvolController < ApplicationController
    include ReverseProxy::Controller

    def index
        # Assuming the WordPress server is being hosted on port 8080
        reverse_proxy "http://localhost:5001", verify_ssl: false do |config|

            # We got a 404!
            config.on_missing do |code, response|
                redirect_to root_url and return
            end

            # There's also other callbacks:
            # - on_set_cookies
            # - on_connect
            # - on_response
            # - on_set_cookies
            # - on_success
            # - on_redirect
            # - on_missing
            # - on_error
            # - on_complete
        end
    end
end