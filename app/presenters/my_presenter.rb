class MyPresenter < Blacklight::IndexPresenter

  def label(field_or_string_or_proc, opts = {})
    # Assuming that :main_title and :sub_title are field names on the Solr document.
    #document.first(:main_title) + " - " + document.first(:sub_title)

    if document.has?(:title_ssi)
      return document.first(:title_ssi)
    elsif document.has?(:title_tfr_siv)
      return document.first(:title_tfr_siv)
    elsif document.has?(:title_tde_siv)
      return document.first(:title_tde_siv)
    elsif document.has?(:title_tfi_siv)
      return document.first(:title_tfi_siv)
    elsif document.has?(:title_tse_siv)
      return document.first(:title_tse_siv)
    end
  end

end