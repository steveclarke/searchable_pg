# frozen_string_literal: true

module SearchablePg
  # App-wide defaults. Every builder may set its own (SearchContent::Base's
  # class DSL); a builder's setting wins.
  #
  # - matching: :any_word (one word of the query is enough; 0.1 behaviour) or
  #   :every_word (every word must match; for names and titles, where a wrong
  #   match is worse than none).
  # - trigram_threshold: near-spelling threshold for every builder. Unset, it
  #   is 0.3 under :any_word and 0.55 under :every_word.
  # - projection_rebuild: :callbacks (search_projection rebuilt on save and on
  #   touch) or :manual (the app calls rebuild_search_projection where the
  #   projection's inputs change).
  class Configuration
    MATCHING = %i[any_word every_word].freeze
    PROJECTION_REBUILD = %i[callbacks manual].freeze

    attr_reader :matching, :trigram_threshold, :projection_rebuild

    def initialize
      @matching = :any_word
      @trigram_threshold = nil
      @projection_rebuild = :callbacks
    end

    def matching=(value)
      @matching = self.class.check(:matching, value, MATCHING)
    end

    def trigram_threshold=(value)
      raise ArgumentError, "trigram_threshold must be between 0 and 1" unless value.nil? || (0..1).cover?(value)
      @trigram_threshold = value
    end

    def projection_rebuild=(value)
      @projection_rebuild = self.class.check(:projection_rebuild, value, PROJECTION_REBUILD)
    end

    def self.check(name, value, allowed)
      return value if allowed.include?(value)
      raise ArgumentError, "#{name} must be one of #{allowed.map(&:inspect).join(", ")}, not #{value.inspect}"
    end
  end
end
