class CreateIndexCursors < ActiveRecord::Migration[8.1]
  def change
    create_table :index_cursors do |t|
      t.string :schema_name, null: false
      t.datetime :last_processed_at
      t.boolean :paused, null: false, default: false
      t.timestamps
    end

    add_index :index_cursors, :schema_name, unique: true
  end
end
