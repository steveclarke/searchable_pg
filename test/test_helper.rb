# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "rails/generators"
require "rails/generators/test_case"
require "searchable_pg"
require "generators/searchable_pg/searchable/searchable_generator"
