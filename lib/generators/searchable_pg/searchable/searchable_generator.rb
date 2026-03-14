# frozen_string_literal: true

require "rails/generators"
require "rails/generators/named_base"
require "rails/generators/active_record"

class SearchablePg::SearchableGenerator < Rails::Generators::NamedBase
  include ActiveRecord::Generators::Migration

  source_root File.expand_path("templates", __dir__)

  argument :search_fields, type: :array, default: [], banner: "field1 field2 field3"

  class_option :project, type: :boolean, default: false, desc: "Add search_projection and projection DSL"
  class_option :skip_model_injection, type: :boolean, default: false, desc: "Do not modify the model file"

  def create_search_content_builder
    if search_fields.any?
      say_status :info, "Configuring search fields: #{search_fields.join(", ")}", :blue
      field_weights = search_fields.each_with_index.map { |field, i| "#{field}:#{%w[A B C D][i] || "D"}" }
      say_status :info, "Field weights: #{field_weights.join(", ")}", :blue
    end

    template "search_content.rb.tt", File.join("app/models/search_content", "#{file_path}.rb")
  end

  def create_search_content_test
    template "search_content_test.rb.tt", File.join("test/models/search_content", "#{file_path}_test.rb")
  end

  def add_search_projection_migration
    return unless options[:project]

    @table_name = table_name

    migration_template "add_search_projection_migration.rb.tt",
      "db/migrate/add_search_projection_to_#{table_name}.rb"
  end

  def add_rebuild_task
    return unless options[:project]

    @task_name = file_path.tr("/", "_")
    template "search_tasks.rake.tt",
      File.join("lib/tasks/search", "rebuild_#{@task_name}.rake")
  end

  def inject_into_model
    return if options[:skip_model_injection]

    model_path = File.join("app/models", "#{file_path}.rb")
    unless File.exist?(model_path)
      say_status :warning, "Model file not found: #{model_path} (skipping injection)", :yellow
      return
    end

    inject_into_class model_path, class_name do
      "  include Searchable\n"
    end

    after_include = "include Searchable"
    inject_into_file model_path, after: /#{Regexp.escape(after_include)}\n/ do
      if options[:project]
        "  searchable_with SearchContent::#{class_name}, project: true\n"
      else
        "  searchable_with SearchContent::#{class_name}\n"
      end
    end
  end

  # Required by Rails::Generators::Migration
  def self.next_migration_number(dirname)
    Time.current.utc.strftime("%Y%m%d%H%M%S")
  end
end
