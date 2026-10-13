# frozen_string_literal: true

require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "active_job/railtie"
require "action_policy"
require "pundit"
require "searchable_pg"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.enable_reloading = false
    config.secret_key_base = "searchable_pg-dummy"
    config.hosts.clear
    config.active_support.deprecation = :raise
    config.logger = Logger.new(nil)
    config.active_job.queue_adapter = :test
  end
end
