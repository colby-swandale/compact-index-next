class CreateDependencies < ActiveRecord::Migration[8.1]
  def change
    create_table :dependencies do |t|
      t.references :version, foreign_key: true
      t.references :rubygem, foreign_key: true
      t.string :requirements
      t.string :scope
      t.string :unresolved_name

      t.timestamps
    end

    add_index :dependencies, :unresolved_name
  end
end
