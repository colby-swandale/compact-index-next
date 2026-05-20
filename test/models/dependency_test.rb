require "test_helper"

class DependencyTest < ActiveSupport::TestCase
  test "requires a version" do
    d = Dependency.new(unresolved_name: "foo")
    assert_not d.valid?
    assert_includes d.errors[:version], "must exist"
  end

  test "rubygem target is optional" do
    d = versions(:rake_13_2_1).dependencies.build(unresolved_name: "json", scope: "runtime")
    assert d.valid?
  end

  test "scope must be runtime or development when present" do
    d = versions(:rake_13_2_1).dependencies.build(unresolved_name: "json", scope: "wrong")
    assert_not d.valid?
    assert_includes d.errors[:scope], "is not included in the list"
  end

  test "associates a version to a target rubygem" do
    dep = dependencies(:rake_runtime_bundler)
    assert_equal rubygems(:rake), dep.version.rubygem
    assert_equal rubygems(:bundler), dep.rubygem
  end
end
