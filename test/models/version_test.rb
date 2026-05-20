require "test_helper"

class VersionTest < ActiveSupport::TestCase
  test "requires number, platform, and rubygem" do
    v = Version.new
    assert_not v.valid?
    assert_includes v.errors[:rubygem], "must exist"
    assert_includes v.errors[:number], "can't be blank"
    assert_includes v.errors[:platform], "can't be blank"
  end

  test "number is unique per rubygem and platform" do
    rake = rubygems(:rake)
    dup = rake.versions.build(number: "13.2.1", platform: "ruby")
    assert_not dup.valid?
    assert_includes dup.errors[:number], "has already been taken"
  end

  test "indexed scope excludes yanked and unindexed" do
    rake = rubygems(:rake)
    rake.versions.create!(number: "13.2.2", platform: "ruby", indexed: false)
    rake.versions.create!(number: "13.2.3", platform: "ruby", indexed: true, yanked_at: Time.current)

    indexed = Version.indexed.where(rubygem: rake)
    assert_includes indexed, versions(:rake_13_2_1)
    assert_equal 1, indexed.size
  end
end
