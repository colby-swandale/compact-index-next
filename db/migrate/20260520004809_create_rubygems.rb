class CreateRubygems < ActiveRecord::Migration[8.1]
  def change
    create_table :rubygems do |t|
      t.string :name
      t.boolean :indexed, default: false, null: false

      t.timestamps
    end

    add_index :rubygems, :name, unique: true
    add_index :rubygems, :indexed
  end
end
