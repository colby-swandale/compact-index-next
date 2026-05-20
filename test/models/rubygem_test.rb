require "test_helper"

class RubygemTest < ActiveSupport::TestCase
  test "requires a name" do
    assert_not Rubygem.new.valid?
  end

  test "name is unique" do
    Rubygem.create!(name: "unique-gem")
    dup = Rubygem.new(name: "unique-gem")
    assert_not dup.valid?
    assert_includes dup.errors[:name], "has already been taken"
  end

  test "has many versions and dependencies through versions" do
    rake = rubygems(:rake)
    assert_includes rake.versions, versions(:rake_13_2_1)
    assert_includes rake.dependencies, dependencies(:rake_runtime_bundler)
  end

  test "indexed scope filters to indexed gems" do
    Rubygem.create!(name: "hidden", indexed: false)
    assert_includes Rubygem.indexed, rubygems(:rake)
    assert_not_includes Rubygem.indexed.map(&:name), "hidden"
  end
end
