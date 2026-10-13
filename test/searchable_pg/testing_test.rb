# frozen_string_literal: true

require "test_helper"
require "searchable_pg/testing/minitest"

class TestingTest < ActiveSupport::TestCase
  include SearchablePg::Testing::Assertions

  test "asserts what a search finds and does not" do
    ada = Person.create!(name: "Ada Moss")
    kit = Person.create!(name: "Kit Moss")
    Person.create!(name: "Ada Marsh")

    assert_finds Person, "ada moss", ada
    assert_finds Person, "moss", [ada, kit], exactly: true
    refute_finds Person, "ada moss", kit
    assert_finds Person, "ada", ada, scope: :search_names
  end

  test "names kinds that match on private columns, and values a result shows" do
    assert_no_private_matches private: {Person => %i[phone]}
    assert_equal ["person matches on legal_name"], SearchablePg::Testing.private_matches(private: {Person => %i[legal_name]})

    Person.create!(name: "Ada Moss", legal_name: "CANARY-1")
    result = SearchablePg::Global::Query.call(user: User.create!(office: true), query: "ada")
    assert_no_leaks result, "CANARY-1"
    assert_equal ["Ada Moss"], SearchablePg::Testing.leaks(result, "Ada Moss", "CANARY-1")
  end
end

require "rspec/expectations"
require "searchable_pg/testing/rspec"

class RSpecMatchersTest < ActiveSupport::TestCase
  include RSpec::Matchers

  test "find_by_search matches, negates and chains" do
    ada = Person.create!(name: "Ada Moss")
    kit = Person.create!(name: "Kit Moss")

    expect(Person).to find_by_search("ada moss", ada)
    expect(Person).not_to find_by_search("ada moss", kit)
    expect(Person).to find_by_search("moss", ada, kit).exactly
    expect(Person).to find_by_search("ada", ada).in_scope(:search_names)
    error = assert_raises(RSpec::Expectations::ExpectationNotMetError) { expect(Person).to find_by_search("ada", kit) }
    assert_includes error.message, "found"
    expect(SearchablePg::Global.registry).to have_no_private_search_matches(private: {Person => %i[phone]})
  end
end
