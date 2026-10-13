# frozen_string_literal: true

module SearchContent
  class OrgName < Base
    matching :every_word
    order_within_rank "orgs.name, orgs.id"

    def self.search_fields = {name: "A"}
  end
end
