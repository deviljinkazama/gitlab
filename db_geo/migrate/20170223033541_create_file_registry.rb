class CreateFileRegistry < ActiveRecord::Migration
  def change
    create_table :file_registries do |t|
      t.string  :file_type, null: false
      t.integer :file_id, null: false
      t.integer :bytes
      t.string  :sha256

      t.datetime :created_at, null: false
    end

    add_index :file_registries, :file_type
    add_index :file_registries, [:file_type, :file_id], { unique: true }
  end
end
