
class ApiAuthenticationController < ApplicationController
  # skip_before_action :authenticate_request
  skip_before_action :verify_authenticity_token

  def authenticate
    puts "####"
    puts params
    command = AuthenticateApiUser.call(params[:email], params[:password])

    if command.success?
      render json: { auth_token: command.result }
    else
      render json: { error: command.errors }, status: :unauthorized
    end
  end
end