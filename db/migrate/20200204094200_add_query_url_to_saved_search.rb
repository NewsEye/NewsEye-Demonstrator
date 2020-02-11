class AddQueryUrlToSavedSearch < ActiveRecord::Migration[5.1]
  def change
    add_column :searches, :query_url, :string
  end
end
