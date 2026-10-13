# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
ENV["RAILS_ENV"] = "test"

require "minitest/autorun"
require "pg"
require "uri"

# The dummy app's database: created on first run, schema loaded every run.
database_url = ENV.fetch("DATABASE_URL", "postgres://postgres:nitro@127.0.0.1:54329/searchable_pg_test")
ENV["DATABASE_URL"] = database_url
begin
  PG.connect(database_url).close
rescue PG::ConnectionBad => error
  raise unless error.message.include?("does not exist")
  uri = URI(database_url)
  admin = PG.connect(host: uri.host, port: uri.port, user: uri.user, password: uri.password, dbname: "postgres")
  admin.exec("CREATE DATABASE #{PG::Connection.quote_ident(uri.path.delete_prefix("/"))}")
  admin.close
end

require_relative "dummy/config/environment"
require "rails/test_help"
require "rails/generators"
require "rails/generators/test_case"
require "generators/searchable_pg/searchable/searchable_generator"

ActiveRecord::Migration.verbose = false
load File.expand_path("dummy/db/schema.rb", __dir__)

class ActiveSupport::TestCase
  self.use_transactional_tests = true

  # Statements run against a table, by its name.
  def queries_on(table)
    sql = []
    callback = ->(*, payload) { sql << payload[:sql] if payload[:sql].include?(%("#{table}")) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    sql
  end

  def with_configuration(**settings)
    previous = SearchablePg.instance_variable_get(:@configuration)
    SearchablePg.reset_configuration!
    settings.each { |name, value| SearchablePg.configuration.public_send(:"#{name}=", value) }
    yield
  ensure
    SearchablePg.instance_variable_set(:@configuration, previous)
  end
end
