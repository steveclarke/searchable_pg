# frozen_string_literal: true

require "test_helper"

# 0.1.0's matching is still the default. The golden file was recorded by
# running 0.1.0's code (13396b9) on the same corpus (test/fixtures/README.md).
class AnyWordTest < ActiveSupport::TestCase
  CORPUS = YAML.load_file(File.expand_path("../fixtures/any_word_corpus.yml", __dir__))
  GOLDEN = JSON.parse(File.read(File.expand_path("../fixtures/any_word_golden.json", __dir__)))

  setup do
    CORPUS.fetch("contacts").each do |row|
      contact = Contact.create!(display_name: row.fetch("name"))
      Array(row["emails"]).each { |email| contact.email_addresses.create!(email:) }
      Array(row["phones"]).each { |number| contact.phone_numbers.create!(number:) }
    end
  end

  test "an unconfigured builder keeps 0.1.0's options" do
    assert_equal :any_word, SearchContent::Contact.matching
    assert_equal({tsearch: {prefix: true, any_word: true, dictionary: "english"}, trigram: {word_similarity: true, threshold: 0.3}}, SearchContent::Contact.using)
    refute_respond_to Contact, :search_ranked
  end

  test "returns exactly 0.1.0's results, in 0.1.0's order" do
    GOLDEN.each do |query, expected|
      assert_equal expected, Contact.search(query).map(&:display_name), query
    end
  end

  test "rebuilds the projection by callbacks: on save and when a child touches it" do
    contact = Contact.create!(display_name: "Jo Bell")
    assert_nil contact.search_projection

    contact.email_addresses.create!(email: "jo@bell.test")
    assert_equal "jo@bell.test", contact.reload.search_projection
    assert_equal contact, Contact.search("jo@bell.test").first
  end
end
