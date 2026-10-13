# frozen_string_literal: true

class Team < ApplicationRecord
  include Searchable

  searchable_with SearchContent::Team
end
