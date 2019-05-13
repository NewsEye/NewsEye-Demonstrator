class RenameNamedEntityTypeToNeType < ActiveRecord::Migration[5.1]
  def change
    rename_column :named_entities, :type, :ne_type
  end
end
