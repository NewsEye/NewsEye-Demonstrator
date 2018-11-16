class AssetsController < ApplicationController
  def locale
    language = params.fetch(:id) { I18n.default_locale.to_s }
    path = "#{language}/translation.json"
    i18nfile = (Rails.application.assets || ::Sprockets::Railtie.build_environment(Rails.application)).find_asset(path)
    render json: i18nfile.source.force_encoding('UTF-8')
  rescue Exception
    raise ActionController::RoutingError.new('Locale not Found')
  end
end