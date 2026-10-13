# frozen_string_literal: true

module SearchContent
  class Person < Base
    matching :every_word
    near_spelling :name, :legal_name
    order_within_rank "people.name, people.id"

    def self.search_fields = {name: "A", legal_name: "A", search_projection: "B"}

    projection do
      project_emails
      project_phones
    end
  end
end
