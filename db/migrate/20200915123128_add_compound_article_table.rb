class AddCompoundArticleTable < ActiveRecord::Migration[5.1]
  def change
    create_table :compound_articles do |t|
      t.string :title
      t.string :issue
      t.references :user, foreign_key: true
      t.string :parts, array: true, default: []
      t.timestamps
    end
  end
end
