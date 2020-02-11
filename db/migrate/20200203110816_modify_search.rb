class ModifySearch < ActiveRecord::Migration[5.1]
  def change
    #remove_column :searches, :query_params, :binary
    #remove_column :searches, :user_id, :integer
    #remove_column :searches, :user_type, :string
    add_column :searches, :query, :jsonb, default: {}
    add_column :searches, :description, :text
    add_foreign_key :searches, :users
  end
end
