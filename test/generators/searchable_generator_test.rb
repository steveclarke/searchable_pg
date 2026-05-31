# frozen_string_literal: true

require "test_helper"

class SearchableGeneratorTest < Rails::Generators::TestCase
  tests SearchablePg::SearchableGenerator
  destination File.expand_path("../tmp/generators", __dir__)

  setup :prepare_destination

  test "generates a Minitest file by default" do
    run_generator %w[Article title]

    assert_file "app/models/search_content/article.rb" do |content|
      assert_includes content, "class Article < SearchContent::Base"
      assert_includes content, 'title: "A"'
    end

    assert_file "test/models/search_content/article_test.rb" do |content|
      assert_includes content, 'require "test_helper"'
      assert_includes content, "class SearchContent::ArticleTest < ActiveSupport::TestCase"
    end
    assert_no_file "spec/models/search_content/article_spec.rb"
  end

  test "generates an RSpec file when the host app uses RSpec files" do
    FileUtils.mkdir_p File.join(destination_root, "spec")
    File.write File.join(destination_root, "spec", "rails_helper.rb"), "# rails helper\n"

    run_generator %w[Article title --project]

    assert_file "spec/models/search_content/article_spec.rb" do |content|
      assert_includes content, 'require "rails_helper"'
      assert_includes content, "RSpec.describe SearchContent::Article, type: :model do"
      assert_includes content, "let(:record) { Article.new }"
      assert_includes content, "expect(builder.search_projection).to be_a(String)"
    end
    assert_no_file "test/models/search_content/article_test.rb"
  end

  test "generates an RSpec file when Rails generator config uses RSpec" do
    application = fake_application_with_test_framework(:rspec)

    with_rails_application(application) do
      run_generator %w[Article title]
    end

    assert_file "spec/models/search_content/article_spec.rb" do |content|
      assert_includes content, 'require "rails_helper"'
      assert_includes content, "RSpec.describe SearchContent::Article, type: :model do"
      assert_includes content, "let(:record) { Article.new }"
    end
    assert_no_file "test/models/search_content/article_test.rb"
  end

  private

  def fake_application_with_test_framework(test_framework)
    options = {rails: {test_framework:}}
    generators = Struct.new(:options).new(options)
    config = Struct.new(:generators).new(generators)

    Struct.new(:config).new(config)
  end

  def with_rails_application(application)
    rails_singleton = class << Rails; self; end
    had_application = Rails.respond_to?(:application)
    original_application = Rails.method(:application) if had_application

    rails_singleton.define_method(:application) { application }
    yield
  ensure
    if had_application
      rails_singleton.define_method(:application) { original_application.call }
    elsif rails_singleton.method_defined?(:application)
      rails_singleton.remove_method(:application)
    end
  end
end
