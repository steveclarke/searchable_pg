# frozen_string_literal: true

require "test_helper"
require "generators/searchable_pg/install/install_generator"
require "generators/searchable_pg/global/global_generator"
require "generators/searchable_pg/global_frontend/global_frontend_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests SearchablePg::InstallGenerator
  destination File.expand_path("../tmp/generators", __dir__)
  setup :prepare_destination

  test "writes today's defaults into the app" do
    run_generator
    assert_file "config/initializers/searchable_pg.rb" do |content|
      assert_includes content, "c.matching = :any_word"
      assert_includes content, "c.projection_rebuild = :callbacks"
      assert_includes content, "searchable_pg #{SearchablePg::VERSION}"
    end
  end

  test "writes the chosen settings" do
    run_generator %w[--matching=every_word --projection-rebuild=manual]
    assert_file "config/initializers/searchable_pg.rb", /c.matching = :every_word/, /c.projection_rebuild = :manual/
  end
end

class GlobalGeneratorTest < Rails::Generators::TestCase
  tests SearchablePg::GlobalGenerator
  destination File.expand_path("../tmp/generators", __dir__)
  setup :prepare_destination

  test "writes a registry for the app's policy library" do
    run_generator %w[--policies=pundit]
    assert_file "config/initializers/global_search.rb", /SearchablePg::Global.define/, /g.authorize_with :pundit/
  end
end

class GlobalFrontendGeneratorTest < Rails::Generators::TestCase
  tests SearchablePg::GlobalFrontendGenerator
  destination File.expand_path("../tmp/generators", __dir__)
  setup :prepare_destination

  test "copies the three files, each naming the gem version" do
    run_generator %w[--path=app/frontend/search]
    %w[searchGroups.ts useRemoteSearch.ts useRecentItems.ts].each do |file|
      assert_file "app/frontend/search/#{file}", /searchable_pg #{Regexp.escape(SearchablePg::VERSION)}/o
    end
  end
end
