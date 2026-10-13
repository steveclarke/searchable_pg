# frozen_string_literal: true

require "searchable_pg"
require "searchable_pg/testing"

# expect(Person).to find_by_search("ada moss", ada)
# expect(Person).not_to find_by_search("ada moss", kit)         # finds none of them
# expect(Person).to find_by_search("ada moss", ada).exactly      # nothing else, in order
# expect(Person).to find_by_search("north", ada).in_scope(:search_names)
RSpec::Matchers.define :find_by_search do |query, *records|
  chain(:in_scope) { |scope| @scope = scope }
  chain(:exactly) { @exactly = true }

  match do |relation|
    @found = SearchablePg::Testing.found(relation, query, scope: @scope || :search)
    @exactly ? @found == records.flatten : (records.flatten - @found).empty?
  end

  match_when_negated do |relation|
    @found = SearchablePg::Testing.found(relation, query, scope: @scope || :search)
    (@found & records.flatten).empty?
  end

  failure_message { "expected #{query.inspect} to find #{records.flatten.inspect}, found #{@found.inspect}" }
  failure_message_when_negated { "expected #{query.inspect} not to find #{(@found & records.flatten).inspect}" }
end

RSpec::Matchers.define :have_no_private_search_matches do |private:|
  match { |registry| (@problems = SearchablePg::Testing.private_matches(registry, private:)).empty? }
  failure_message { @problems.join("\n") }
end
