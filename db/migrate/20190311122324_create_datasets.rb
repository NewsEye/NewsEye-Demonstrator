class CreateDatasets < ActiveRecord::Migration[5.1]
  def change
    create_table :datasets do |t|
      t.string :title
      t.references :user, foreign_key: true
      t.string :searches, array: true, default: []
      t.string :articles, array: true, default: []
      t.string :issues, array: true, default: []
      t.timestamps
    end
  end
end
