class AddDatasetAndSearchToTask < ActiveRecord::Migration[5.1]
  def change
    add_reference :tasks, :dataset, foreign_key: true
    add_reference :tasks, :search, foreign_key: true
  end
end
