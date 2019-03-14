class CreateFeedbacks < ActiveRecord::Migration[5.1]
  def change
    create_table :feedbacks do |t|
      t.string :email
      t.string :name
      t.string :page
      t.text :text

      t.timestamps
    end
  end
end
