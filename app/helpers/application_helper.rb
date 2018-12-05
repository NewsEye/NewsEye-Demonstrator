module ApplicationHelper
  def convert_date_to_locale_facet(options={})
    I18n.localize Date.parse(options)
  end

  def convert_date_to_locale(options={})
    I18n.localize Date.parse(options[:value].first)
  end

  def convert_language_to_locale(options={})
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

  def get_collection_title_from_id(options={})
    Newspaper.find(options).title
  end
end
