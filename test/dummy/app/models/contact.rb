# frozen_string_literal: true

# 0.1's defaults: :any_word, projection rebuilt by callbacks (Outport's shape).
class Contact < ApplicationRecord
  include Searchable

  has_many :email_addresses
  has_many :phone_numbers

  searchable_with SearchContent::Contact, project: true
end
