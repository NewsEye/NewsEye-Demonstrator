class CreateExperiment < ActiveRecord::Migration[6.1]
    def change
        create_table :experiments do |t|
            t.string :title
            t.references :user, foreign_key: true
            t.jsonb :description, default: {children:[]}
            t.timestamps
        end
        add_index :experiments, [:title, :user_id], unique: true
    end
end
