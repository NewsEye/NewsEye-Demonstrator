class CreateNamedEntities < ActiveRecord::Migration[5.1]
  def change
    create_table :named_entities do |t|
      t.string :label
      t.string :type
      t.string :kb_url

      t.timestamps
    end
    add_index :named_entities, :label
  end
end
