class SetDefaultDatasetsDocuments < ActiveRecord::Migration[5.1]
  def change
    change_column :datasets, :documents, :jsonb, default: []
  end
end
