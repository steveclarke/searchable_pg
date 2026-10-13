# frozen_string_literal: true

require "rails/generators"

# Writes config/initializers/global_search.rb, the app's registry of kinds.
class SearchablePg::GlobalGenerator < Rails::Generators::Base
  source_root File.expand_path("templates", __dir__)

  class_option :policies, type: :string, default: "action_policy", enum: %w[action_policy pundit], desc: "The app's policy library"

  def create_registry
    template "global_search.rb.tt", "config/initializers/global_search.rb"
  end
end
