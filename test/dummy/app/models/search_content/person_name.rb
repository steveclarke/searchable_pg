# frozen_string_literal: true

# Name only, so a phone or email never confirms who owns it.
module SearchContent
  class PersonName < Person
    def self.search_fields = {name: "A"}
    near_spelling :name
  end
end
