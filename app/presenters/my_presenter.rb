class MyPresenter < Blacklight::IndexPresenter

  def label(field_or_string_or_proc, opts = {})
    config = Blacklight::Configuration::NullField.new
    value = case field_or_string_or_proc
    when Symbol
      config = field_config(field_or_string_or_proc)
      document[field_or_string_or_proc]
    when Proc
      field_or_string_or_proc.call(document, opts)
    when String
      if field_or_string_or_proc == 'title_ssi'
        document.first(:title_ssi)
      elsif document.has?(:title_tfr_siv)
        document.first(:title_tfr_siv)
      elsif document.has?(:title_tde_siv)
        document.first(:title_tde_siv)
      elsif document.has?(:title_tfi_siv)
        document.first(:title_tfi_siv)
      elsif document.has?(:title_tse_siv)
        document.first(:title_tse_siv)
      else
        field_or_string_or_proc
      end
    end
    value ||= document.id
    field_values(config, value: value)
  end

end