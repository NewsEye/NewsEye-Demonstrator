class AddSubtaskBooleanToTask < ActiveRecord::Migration[5.1]
  def change
    change_table(:tasks) do |t|
      t.boolean :subtask, :default => false
    end
  end
end
