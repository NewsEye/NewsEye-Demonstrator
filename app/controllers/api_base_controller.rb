class ApiBaseController < ApplicationController
  protect_from_forgery with: :null_session, if: :json_request
  # before_action :authenticate_request, if: :json_request

  attr_reader :current_user

  private

  def authenticate_request
    @current_user = AuthorizeApiRequest.call(request.headers).result
    render json: { error: 'Not Authorized' }, status: 401 unless @current_user
  end
end