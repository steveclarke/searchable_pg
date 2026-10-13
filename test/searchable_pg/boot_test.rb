# frozen_string_literal: true

require "test_helper"

class BootTest < ActiveSupport::TestCase
  test "the dummy app boots on the gem's constants and frozen settings" do
    assert_equal SearchablePg::Searchable, ::Searchable
    assert_equal SearchablePg::SearchContent::Base, ::SearchContent::Base
    assert_predicate SearchablePg.configuration, :frozen?
    assert_raises(FrozenError) { SearchablePg.configuration.matching = :every_word }
  end
end
