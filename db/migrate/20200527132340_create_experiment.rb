class CreateExperiment < ActiveRecord::Migration[5.1]
  def change
    create_table :experiments do |t|
      t.string :title
      t.references :user, foreign_key: true
      t.jsonb :description
      t.timestamps
    end
  end
end
