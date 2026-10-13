# frozen_string_literal: true

require "pg_search"
require "active_record"
require "active_support"

require_relative "searchable_pg/version"
require_relative "searchable_pg/configuration"
require_relative "searchable_pg/normalize"
require_relative "searchable_pg/projections"
require_relative "searchable_pg/searchable"
require_relative "searchable_pg/search_content/base"
require_relative "searchable_pg/railtie" if defined?(Rails::Railtie)

module SearchablePg
  # Global search is loaded only when an app refers to it.
  autoload :Global, "searchable_pg/global"
  autoload :RebuildProjectionsJob, "searchable_pg/rebuild_projections_job"

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    # Set once, in config/initializers/searchable_pg.rb. The settings are
    # frozen when the app finishes booting.
    #
    #   SearchablePg.configure do |c|
    #     c.matching = :every_word
    #   end
    def configure
      yield configuration
      configuration
    end

    # Tests only: back to the defaults, unfrozen.
    def reset_configuration!
      @configuration = Configuration.new
    end

    def normalize(query) = Normalize.call(query)
  end
end

# Register top-level constants so consumers can write
# `include Searchable` and `SearchContent::Room < SearchContent::Base`
# without namespacing. Set at require time because class
# inheritance (`< SearchContent::Base`) is evaluated when
# the file is parsed — initializers and on_load hooks run too late.
# Requiring "searchable_pg/no_aliases" first leaves them out.
unless defined?(SearchablePg::NO_ALIASES)
  ::Searchable = SearchablePg::Searchable unless defined?(::Searchable)
  unless defined?(::SearchContent)
    ::SearchContent = Module.new
    ::SearchContent::Base = SearchablePg::SearchContent::Base
  end
end
