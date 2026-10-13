# frozen_string_literal: true

module SearchContent
  class Event < Base
    matching :every_word
    near_spelling :title
    order_within_rank "events.title, events.id"

    def self.search_fields = {title: "A", body: "C"}
  end
end
