class AddTaskReferenceToExperiment < ActiveRecord::Migration[5.1]
  def change
    add_reference :experiments, :task, foreign_key: true
  end
end
