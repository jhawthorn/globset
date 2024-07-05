# frozen_string_literal: true

require "test_helper"
require "json"

class TestCodewners < Minitest::Test
  # Patterns taken from https://github.com/hmarr/codeowners test suite
  PATTERNS = JSON.parse(File.read("#{__dir__}/fixtures/codeowners_patterns.json"))

  PATTERNS.each do |patterns|
    name, pattern, paths = patterns.values_at("name", "pattern", "paths")
    test_name = name.gsub(/[^a-z]/i, "_")

    define_method("test_#{test_name}") do
      set = Globset::NFA.new([pattern])
      paths.each do |path, expected|
        match = set.match(path)
        if expected
          assert match, "expected #{pattern.inspect} to match #{path.inspect}"
        else
          refute match, "expected #{pattern.inspect} not to match #{path.inspect}"
        end
      end
    end
  end
end
