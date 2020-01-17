class ModifyDatasetsToJsonb < ActiveRecord::Migration[5.1]
  def change
    remove_column :datasets, :articles, :text
    remove_column :datasets, :searches, :text
    remove_column :datasets, :issues, :text
    add_column :datasets, :documents, :jsonb
  end
end
