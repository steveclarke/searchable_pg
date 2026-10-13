# frozen_string_literal: true

require "rails/generators"

# Writes config/initializers/searchable_pg.rb with the gem's current defaults
# spelled out, so an app's results do not move when a later major version
# changes a default.
class SearchablePg::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  class_option :matching, type: :string, default: "any_word", enum: %w[any_word every_word], desc: "App-wide matching"
  class_option :projection_rebuild, type: :string, default: "callbacks", enum: %w[callbacks manual], desc: "How projections are rebuilt"

  def create_initializer
    template "searchable_pg.rb.tt", "config/initializers/searchable_pg.rb"
  end
end
