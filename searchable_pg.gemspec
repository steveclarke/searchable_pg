# frozen_string_literal: true

require_relative "lib/searchable_pg/version"

Gem::Specification.new do |spec|
  spec.name = "searchable_pg"
  spec.version = SearchablePg::VERSION
  spec.authors = ["Steve Clarke"]
  spec.email = ["steve@sevenview.ca"]

  spec.summary = "Opinionated full-text search for ActiveRecord + PostgreSQL"
  spec.description = "Searchable concern and SearchContent builder pattern on top of pg_search. " \
    "Provides tsearch + trigram dual search strategy with denormalized projections for association data."
  spec.homepage = "https://github.com/steveclarke/searchable_pg"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir["{lib}/**/*", "LICENSE.txt", "README.md"]
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "pg_search"
  spec.add_dependency "activerecord", ">= 7.0"
  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "railties", ">= 7.0"
end
