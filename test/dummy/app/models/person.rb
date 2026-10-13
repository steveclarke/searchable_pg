# frozen_string_literal: true

# :every_word with a manual projection, as 135 Main runs it; sample rows are
# hidden by a default scope.
class Person < ApplicationRecord
  include Searchable

  has_many :email_addresses
  has_many :phone_numbers

  default_scope { where(sample: false) }
  scope :including_sample, -> { unscope(where: :sample) }

  searchable_with SearchContent::Person, project: true, rebuild: :manual,
    rebuild_lock: ->(id, &write) { Person.locked << id; write.call }
  searchable_with SearchContent::PersonName, scope: :search_names

  def self.locked = (@locked ||= [])
end
