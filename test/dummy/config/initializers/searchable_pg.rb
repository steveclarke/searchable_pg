# frozen_string_literal: true

# The dummy app runs on 0.1's defaults; builders that want :every_word say so.
SearchablePg.configure do |c|
  c.matching = :any_word
  c.projection_rebuild = :callbacks
end
