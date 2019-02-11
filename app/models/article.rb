class Article < ActiveFedora::Base

  include Hydra::AccessControls::Permissions
  include Hydra::Works::WorkBehavior

  property :title, predicate: ::RDF::Vocab::DC.title, multiple: false do |index|
    index.as :text_en_searchable_uniq, :text_fr_searchable_uniq, :text_de_searchable_uniq, :text_fi_searchable_uniq, :text_se_searchable_uniq
  end
  property :all_text, predicate: ::RDF::Vocab::CNT.ContentAsText, multiple: false do |index|
    index.as :text_en_searchable_uniq, :text_fr_searchable_uniq, :text_de_searchable_uniq, :text_fi_searchable_uniq, :text_se_searchable_uniq
  end
  property :date_created, predicate: ::RDF::Vocab::DC.created, multiple: false do |index|
    index.type :date
    index.as :date_searchable_uniq, :symbol
  end
  property :language, predicate: ::RDF::Vocab::DC11.language, multiple: false do |index|
    index.type :string
    index.as :string_searchable_uniq
  end
  property :canvases_parts, predicate: ::RDF::Vocab::DC.isPartOf, multiple: true do |index|
    index.as :string_stored_multi
  end

  def issue
    issues = member_of.select { |v| v.instance_of?(Issue) }
    issues[0] unless issues.empty?
  end

  def to_solr
    solr_doc = super
    solr_doc['level'] = '0.articles'
    solr_doc['from_issue_ssi'] = issue.id
    case issue.language
    when 'fr'
      solr_doc.except! 'all_text_tde_siv', 'all_text_ten_siv', 'all_text_tfi_siv', 'all_text_tse_siv'
      solr_doc.except! 'title_tde_siv', 'title_ten_siv', 'title_tfi_siv', 'title_tse_siv'
    when 'de'
      solr_doc.except! 'all_text_ten_siv', 'all_text_tfr_siv', 'all_text_tfi_siv', 'all_text_tse_siv'
      solr_doc.except! 'title_ten_siv', 'title_tfr_siv', 'title_tfi_siv', 'title_tse_siv'
    when 'fi'
      solr_doc.except! 'all_text_tde_siv', 'all_text_tfr_siv', 'all_text_ten_siv', 'all_text_tse_siv'
      solr_doc.except! 'title_tde_siv', 'title_tfr_siv', 'title_ten_siv', 'title_tse_siv'
    when 'se'
      solr_doc.except! 'all_text_tde_siv', 'all_text_tfr_siv', 'all_text_tfi_siv', 'all_text_ten_siv'
      solr_doc.except! 'title_tde_siv', 'title_tfr_siv', 'title_tfi_siv', 'title_ten_siv'
    else
      solr_doc.except! 'all_text_tde_siv', 'all_text_tfr_siv', 'all_text_tfi_siv', 'all_text_tse_siv' # keep english
      solr_doc.except! 'title_tde_siv', 'title_tfr_siv', 'title_tfi_siv', 'title_tse_siv'
    end
  end
end
