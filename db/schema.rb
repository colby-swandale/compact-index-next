# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_20_010100) do
  create_table "build_artifacts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "platform", null: false
    t.string "ruby_abi", null: false
    t.string "sha256", limit: 64, null: false
    t.integer "size"
    t.string "source_url"
    t.datetime "updated_at", null: false
    t.integer "version_id", null: false
    t.index ["sha256"], name: "index_build_artifacts_on_sha256", unique: true
    t.index ["version_id", "platform", "ruby_abi"], name: "index_build_artifacts_on_version_platform_abi", unique: true
    t.index ["version_id"], name: "index_build_artifacts_on_version_id"
  end

  create_table "dependencies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "requirements"
    t.integer "rubygem_id"
    t.string "scope"
    t.string "unresolved_name"
    t.datetime "updated_at", null: false
    t.integer "version_id"
    t.index ["rubygem_id"], name: "index_dependencies_on_rubygem_id"
    t.index ["unresolved_name"], name: "index_dependencies_on_unresolved_name"
    t.index ["version_id"], name: "index_dependencies_on_version_id"
  end

  create_table "index_cursors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_processed_at"
    t.boolean "paused", default: false, null: false
    t.string "schema_name", null: false
    t.datetime "updated_at", null: false
    t.index ["schema_name"], name: "index_index_cursors_on_schema_name", unique: true
  end

  create_table "rubygems", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "indexed", default: false, null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["indexed"], name: "index_rubygems_on_indexed"
    t.index ["name"], name: "index_rubygems_on_name", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.text "authors"
    t.datetime "built_at"
    t.string "canonical_number"
    t.text "cert_chain"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "full_name"
    t.string "gem_full_name"
    t.string "gem_platform"
    t.boolean "indexed", default: true
    t.string "info_checksum"
    t.boolean "latest"
    t.string "licenses"
    t.json "metadata", default: {}, null: false
    t.string "number"
    t.string "platform"
    t.integer "position"
    t.boolean "prerelease"
    t.string "required_ruby_version"
    t.string "required_rubygems_version"
    t.text "requirements"
    t.integer "rubygem_id", null: false
    t.string "sha256"
    t.integer "size"
    t.string "spec_sha256", limit: 44
    t.text "summary"
    t.datetime "updated_at", null: false
    t.datetime "yanked_at"
    t.string "yanked_info_checksum"
    t.index ["built_at"], name: "index_versions_on_built_at"
    t.index ["canonical_number", "rubygem_id", "platform"], name: "index_versions_on_canonical_number_and_rubygem_id_and_platform", unique: true
    t.index ["full_name"], name: "index_versions_on_full_name"
    t.index ["indexed", "yanked_at"], name: "index_versions_on_indexed_and_yanked_at"
    t.index ["number"], name: "index_versions_on_number"
    t.index ["position", "rubygem_id"], name: "index_versions_on_position_and_rubygem_id"
    t.index ["prerelease"], name: "index_versions_on_prerelease"
    t.index ["rubygem_id", "number", "platform"], name: "index_versions_on_rubygem_id_and_number_and_platform", unique: true
    t.index ["rubygem_id"], name: "index_versions_on_rubygem_id"
  end

  add_foreign_key "build_artifacts", "versions"
  add_foreign_key "dependencies", "rubygems"
  add_foreign_key "dependencies", "versions"
  add_foreign_key "versions", "rubygems"
end
