# frozen_string_literal: true

module SearchContent
  class Team < Base
    matching :every_word
    order_within_rank "teams.name, teams.id"

    def self.search_fields = {name: "A"}
  end
end
