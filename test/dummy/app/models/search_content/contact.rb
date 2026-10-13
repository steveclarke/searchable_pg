# frozen_string_literal: true

module SearchContent
  class Contact < SearchContent::Base
    def self.search_fields = {display_name: "A", search_projection: nil}

    def self.scope_options = {ignoring: :accents}

    projection do
      assoc(:email_addresses) { |e| e.email }
      assoc(:phone_numbers) { |p| p.number }
    end
  end
end
