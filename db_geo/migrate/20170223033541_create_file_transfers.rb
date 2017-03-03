class CreateGeoFileTransfers < ActiveRecord::Migration
  def change
    create_table :geo_file_transfers do |t|
      t.string  :file_type, null: false
      t.integer :file_id, null: false
      t.integer :bytes
      t.string  :sha256

      t.datetime :created_at, null: false
    end

    add_index :geo_file_transfers, :file_type
  end
end
