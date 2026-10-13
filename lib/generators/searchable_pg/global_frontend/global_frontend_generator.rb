# frozen_string_literal: true

require "rails/generators"

# Copies the command palette helpers into the app: searchGroups.ts,
# useRemoteSearch.ts and useRecentItems.ts. Each carries the gem version it
# came from; re-running after an upgrade shows the differences.
class SearchablePg::GlobalFrontendGenerator < Rails::Generators::Base
  source_root File.expand_path("../../../../frontend", __dir__)

  class_option :path, type: :string, default: "app/frontend/lib/global-search", desc: "Where the files go"

  def copy_files
    %w[searchGroups.ts useRemoteSearch.ts useRecentItems.ts].each do |file|
      copy_file file, File.join(options[:path], file)
    end
  end
end
