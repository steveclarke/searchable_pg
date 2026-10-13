# frozen_string_literal: true

require "searchable_pg"
require "searchable_pg/testing"

module SearchablePg
  module Testing
    # include SearchablePg::Testing::Assertions in ActiveSupport::TestCase.
    module Assertions
      # assert_finds Person, "ada moss", ada            (ada among the results)
      # assert_finds Person, "ada moss", [ada], exactly: true
      def assert_finds(relation, query, *records, scope: :search, exactly: false)
        found = Testing.found(relation, query, scope:)
        expected = records.flatten
        if exactly
          assert_equal expected, found, "#{scope}(#{query.inspect})"
        else
          missing = expected - found
          assert_empty missing, "#{scope}(#{query.inspect}) did not find #{missing.inspect}; found #{found.inspect}"
        end
      end

      def refute_finds(relation, query, *records, scope: :search)
        found = Testing.found(relation, query, scope:) & records.flatten
        assert_empty found, "#{scope}(#{query.inspect}) found #{found.inspect}"
      end

      def assert_no_private_matches(registry = Global.registry, private:)
        problems = Testing.private_matches(registry, private:)
        assert_empty problems, problems.join("\n")
      end

      def assert_no_leaks(result, *values)
        leaked = Testing.leaks(result, *values)
        assert_empty leaked, "search result shows #{leaked.inspect}"
      end
    end
  end
end
