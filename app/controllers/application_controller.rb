class ApplicationController < ActionController::Base
  helper Openseadragon::OpenseadragonHelper
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller
  include Hydra::Controller::ControllerBehavior
  layout 'blacklight'

  protect_from_forgery with: :exception

  before_action :set_locale, :create_feedback

  # Automatically set locale to all generated URLs
  def default_url_options
    { locale: I18n.locale }
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

end
