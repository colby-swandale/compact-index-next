class CreateVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :versions do |t|
      t.references :rubygem, null: false, foreign_key: true
      t.string :number
      t.string :platform
      t.string :full_name
      t.string :gem_full_name
      t.string :gem_platform
      t.string :canonical_number
      t.boolean :indexed, default: true
      t.boolean :latest
      t.boolean :prerelease
      t.integer :position
      t.string :info_checksum
      t.string :yanked_info_checksum
      t.datetime :yanked_at
      t.datetime :built_at
      t.string :sha256
      t.string :spec_sha256, limit: 44
      t.string :required_ruby_version
      t.string :required_rubygems_version
      t.text :requirements
      t.text :authors
      t.text :description
      t.text :summary
      t.text :cert_chain
      t.string :licenses
      t.json :metadata, default: {}, null: false
      t.integer :size

      t.timestamps
    end

    add_index :versions, [ :rubygem_id, :number, :platform ], unique: true
    add_index :versions, [ :canonical_number, :rubygem_id, :platform ], unique: true,
      name: "index_versions_on_canonical_number_and_rubygem_id_and_platform"
    add_index :versions, :full_name
    add_index :versions, [ :indexed, :yanked_at ]
    add_index :versions, :number
    add_index :versions, :prerelease
    add_index :versions, :built_at
    add_index :versions, [ :position, :rubygem_id ]
  end
end
