class CreateBuildArtifacts < ActiveRecord::Migration[8.1]
  def change
    create_table :build_artifacts do |t|
      t.references :version, null: false, foreign_key: true
      t.string :platform, null: false
      t.string :ruby_abi, null: false
      t.string :sha256, null: false, limit: 64
      t.integer :size
      t.string :source_url
      t.timestamps
    end

    add_index :build_artifacts, :sha256, unique: true
    add_index :build_artifacts, [ :version_id, :platform, :ruby_abi ], unique: true,
      name: "index_build_artifacts_on_version_platform_abi"
  end
end
