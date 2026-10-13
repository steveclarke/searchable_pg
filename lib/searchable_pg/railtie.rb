# frozen_string_literal: true

module SearchablePg
  class Railtie < Rails::Railtie
    # Top-level constants (Searchable, SearchContent::Base) are
    # registered at require time in searchable_pg.rb because class
    # inheritance evaluates before initializers run.

    rake_tasks do
      load File.expand_path("../tasks/searchable_pg.rake", __dir__)
    end

    # Settings are read while models load; changing them later would leave
    # loaded models on the old ones.
    # A registry names the app's models; rebuild it after a code reload.
    config.to_prepare do
      SearchablePg::Global.reset! unless SearchablePg.autoload?(:Global)
    end

    config.after_initialize do
      SearchablePg.configuration.freeze
    end
  end
end
