class CreateTasks < ActiveRecord::Migration[5.1]
  def change
    create_table :tasks do |t|
      t.references :user, foreign_key: true
      t.string :status
      t.datetime :started
      t.datetime :finished
      t.string :type
      t.text :parameters
      t.text :results

      t.timestamps
    end
  end
end
