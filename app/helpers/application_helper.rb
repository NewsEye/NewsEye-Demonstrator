module ApplicationHelper
  def convert_date_to_locale options={}
    puts options
    options
  end

  def convert_language_to_locale options={}
    puts options
    case options
    when 'fr'
      t('newseye.language.fr')
    when 'fi'
      t('newseye.language.fi')
    when 'en'
      t('newseye.language.en')
    when 'de'
      t('newseye.language.de')
    end
  end
end
