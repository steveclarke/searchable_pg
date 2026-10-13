# frozen_string_literal: true

class Event < ApplicationRecord
  include Searchable

  searchable_with SearchContent::Event
end
