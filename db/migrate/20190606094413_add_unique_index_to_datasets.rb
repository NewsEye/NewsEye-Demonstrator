class AddUniqueIndexToDatasets < ActiveRecord::Migration[5.1]
  def change
    add_index :datasets, [:title, :user_id], unique: true
  end
end
