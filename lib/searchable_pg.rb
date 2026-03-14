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
