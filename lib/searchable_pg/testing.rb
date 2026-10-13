# frozen_string_literal: true

module SearchablePg
  # Checks for an app's own tests. Load the framework's helpers with
  # `require "searchable_pg/testing/rspec"` or `require "searchable_pg/testing/minitest"`.
  module Testing
    # Kinds whose search matches on a private column: a match confirms the
    # value to the searcher even when nothing private is shown.
    #
    #   SearchablePg::Testing.private_matches(private: {Person => %i[phone email]})
    #   # => ["person matches on email"]
    def self.private_matches(registry = Global.registry, private:)
      registry.kinds.flat_map do |kind|
        columns = Array(private[kind.model]).map(&:to_sym)
        builder = kind.model.try(:searchable_pg_builders)&.dig(kind.scope_name)
        next [] unless builder && columns.any?
        fields = builder.search_fields
        matched = (fields.is_a?(Hash) ? fields.keys : Array(fields)).map(&:to_sym)
        (matched & columns).map { |column| "#{kind.type} matches on #{column}" }
      end
    end

    # The given values that appear anywhere in a search result or envelope,
    # for a test that fills private fields with marker values and searches.
    def self.leaks(result, *values)
      text = (result.respond_to?(:to_h) ? result.to_h : result).to_json
      values.flatten.map(&:to_s).select { |value| text.include?(value) }
    end

    # The records a search scope returns, in order.
    def self.found(relation, query, scope: :search) = relation.public_send(scope, query).to_a
  end
end
