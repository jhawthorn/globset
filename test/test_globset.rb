# frozen_string_literal: true

require "test_helper"

class TestGlobset < Minitest::Test
  def test_nfa
    set = Globset::NFA.new([
      "**/.keep",
      "lib/**/*.rb",
      "app/views/**/*.erb",
      "app/controllers/application_controller.rb",
      "Rakefile"
    ])

    assert set.match(".keep")
    assert set.match("foo/.keep")
    assert set.match("foo/bar/.keep")
    assert set.match("Rakefile")
    refute set.match("Gemfile")
    assert set.match("app/views/test.erb")
    assert set.match("app/views/something/test.erb")
    refute set.match("test.rb")
    assert set.match("lib/test.rb")
  end
end
