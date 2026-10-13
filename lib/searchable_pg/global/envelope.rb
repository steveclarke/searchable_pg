# frozen_string_literal: true

module SearchablePg
  module Global
    # One record as it leaves the server: only these fields, declared by the
    # kind, so nothing else about the record can reach the searcher.
    # snippet is escaped HTML whose only tag is <mark>, or nil.
    Item = Data.define(:id, :title, :subtitle, :url, :snippet) do
      def initialize(id:, title:, subtitle: nil, url: nil, snippet: nil) = super
    end

    # One kind's results, best match first. more: a further match exists
    # (never a count).
    Group = Data.define(:type, :label, :icon, :more, :results)

    # top_hit: {kind:, id:} of the result Enter opens, or nil.
    # partial: a kind ran out of time and was left out.
    Result = Data.define(:query, :top_hit, :partial, :groups) do
      def empty? = groups.empty?

      def to_h
        {
          query:,
          top_hit:,
          partial:,
          groups: groups.map { |group| group.to_h.merge(results: group.results.map(&:to_h)) }
        }
      end

      def as_json(*) = to_h.as_json
    end
  end
end
