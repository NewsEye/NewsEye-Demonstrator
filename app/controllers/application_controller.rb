class ApplicationController < ActionController::Base
  helper Openseadragon::OpenseadragonHelper
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller
  include Hydra::Controller::ControllerBehavior
  layout 'blacklight'

  protect_from_forgery with: :exception, unless: :json_request
  protect_from_forgery with: :null_session, if: :json_request
  before_action :authenticate_user!, unless: :json_request
  before_action :authorize_api_request, except: [:authenticate], if: :json_request
  before_action :authorize_api_request, if: :controller_is_iiif
  before_action :set_locale, unless: :json_request
  before_action :create_feedback, unless: :json_request
  #TODO not set locale before every action to avoid ?locale=fr in url sometimes (iiif for exemple)

  # Automatically set locale to all generated URLs
  def default_url_options
    { locale: I18n.locale }
  end

  def append_info_to_payload(payload)
    super
    payload[:ip] = request.remote_ip
    if current_user
      payload[:user_id] = current_user.id
      payload[:user_email] = current_user.email
    end
    exceptions = %w(controller action format id)
    payload[:params] = request.filtered_parameters
  end

  private

  def set_locale
    if !params[:locale]
      # See https://github.com/iain/http_accept_language/tree/master auto-detect language based on HTTP header
      I18n.locale = http_accept_language.compatible_language_from(I18n.available_locales)
      logger.debug "* Locale set to '#{I18n.locale}'"
    else
      I18n.locale = params[:locale] || I18n.default_locale
    end
  end

  def create_feedback
    @feedback = Feedback.new
  end

  def json_request
    request.content_type == 'application/json'
  end

  def controller_is_iiif
    self.controller_name == 'iiif' || self.controller_name == 'images'
  end

  def authorize_api_request
    puts self.controller_name
    return if self.controller_name == "sessions" or self.controller_name == "registrations" or self.controller_name == "investigator"
    @current_user = AuthorizeApiRequest.call(request.headers).result
    unless current_user
      respond_to do |format|
        format.html { store_preferred_view }
        format.json { render json: { error: 'Not Authorized' }, status: 401 }
      end
    end
  end

end
