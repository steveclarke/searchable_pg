# frozen_string_literal: true

class EmailAddress < ApplicationRecord
  belongs_to :person, optional: true
  belongs_to :contact, optional: true, touch: true
end
