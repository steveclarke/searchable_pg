# frozen_string_literal: true

require "pg_search"
require "active_record"
require "active_support"

require_relative "searchable_pg/version"
require_relative "searchable_pg/searchable"
require_relative "searchable_pg/search_content/base"
require_relative "searchable_pg/railtie" if defined?(Rails::Railtie)

module SearchablePg
end

# Register top-level constants so consumers can write
# `include Searchable` and `SearchContent::Room < SearchContent::Base`
# without namespacing. Set at require time because class
# inheritance (`< SearchContent::Base`) is evaluated when
# the file is parsed — initializers and on_load hooks run too late.
::Searchable = SearchablePg::Searchable unless defined?(::Searchable)
unless defined?(::SearchContent)
  ::SearchContent = Module.new
  ::SearchContent::Base = SearchablePg::SearchContent::Base
end
