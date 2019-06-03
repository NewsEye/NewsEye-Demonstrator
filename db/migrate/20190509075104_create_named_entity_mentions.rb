class CreateNamedEntityMentions < ActiveRecord::Migration[5.1]
  def change
    create_table :named_entity_mentions do |t|
      t.string :mention
      t.string :doc_id
      t.references :named_entity, foreign_key: true
      t.float :detection_confidence
      t.float :linking_confidence
      t.float :stance
      t.string :position
      t.text :iiif_annotations

      t.timestamps
    end
    add_index :named_entity_mentions, :doc_id
  end
end
