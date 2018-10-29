class ApplicationController < ActionController::Base
  helper Openseadragon::OpenseadragonHelper
  # Adds a few additional behaviors into the application controller
  include Blacklight::Controller
  include Hydra::Controller::ControllerBehavior
  layout 'blacklight'

  protect_from_forgery with: :exception

  before_action :set_locale, :set_base_domain

  private
  def set_locale
    unless request.fullpath.start_with? '/iiif'
      I18n.locale = params[:locale] || I18n.default_locale
      Rails.application.routes.default_url_options[:locale]= I18n.locale
    else
      Rails.application.routes.default_url_options.delete(:locale)
    end
  end

  def set_base_domain
    pp request.host_with_port
  end
end
