# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < ActiveSupport::TestCase
  test "defaults are 0.1.0's" do
    config = SearchablePg::Configuration.new
    assert_equal [:any_word, nil, :callbacks], [config.matching, config.trigram_threshold, config.projection_rebuild]
  end

  test "refuses unknown settings" do
    config = SearchablePg::Configuration.new
    assert_raises(ArgumentError) { config.matching = :all_words }
    assert_raises(ArgumentError) { config.projection_rebuild = :sometimes }
    assert_raises(ArgumentError) { config.trigram_threshold = 2 }
  end

  test "an app setting reaches builders that set nothing themselves" do
    builder = Class.new(SearchablePg::SearchContent::Base) { def self.search_fields = {name: "A"} }
    with_configuration(matching: :every_word, trigram_threshold: 0.4) do
      assert_equal :every_word, builder.matching
      assert_equal({word_similarity: true, threshold: 0.4, only: [:name]}, builder.using[:trigram])
    end
    assert_equal :any_word, builder.matching
  end

  test "a builder's own setting wins over the app's" do
    builder = Class.new(SearchablePg::SearchContent::Base) do
      matching :any_word
      dictionary :english
      trigram_threshold 0.25
      def self.search_fields = {name: "A"}
    end
    with_configuration(matching: :every_word) do
      assert_equal({tsearch: {prefix: true, any_word: true, dictionary: "english"}, trigram: {word_similarity: true, threshold: 0.25}}, builder.using)
    end
  end
end
