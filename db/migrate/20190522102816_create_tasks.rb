class CreateTasks < ActiveRecord::Migration[5.1]
  def change
    create_table :tasks do |t|
      t.references :user, foreign_key: true
      t.string :status
      t.string :uuid
      t.datetime :started
      t.datetime :finished
      t.string :task_type
      t.json :parameters
      t.json :results

      t.timestamps
    end
    add_index :tasks, :uuid
  end
end
