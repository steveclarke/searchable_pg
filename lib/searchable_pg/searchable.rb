# frozen_string_literal: true

# Provides full-text search capabilities to ActiveRecord
# models using PostgreSQL's text search via pg_search.
#
# Accepts a SearchContent builder class that defines fields,
# weights, and search method. Optionally manages a
# search_projection column for associated-data search.
#
#   class Item < ApplicationRecord
#     include Searchable
#     searchable_with SearchContent::Item, project: true
#   end
module SearchablePg
  module Searchable
    extend ActiveSupport::Concern

    class_methods do
      def searchable_with(content_builder, project: false)
        unless content_builder.respond_to?(:search_fields) &&
            content_builder.respond_to?(:using)
          raise ArgumentError,
            "builder must respond to .search_fields/.using"
        end

        include PgSearch::Model

        options = {
          against: content_builder.search_fields,
          using: content_builder.using
        }
        if content_builder.respond_to?(:scope_options)
          options.merge!(content_builder.scope_options)
        end

        pg_search_scope :search, **options

        return unless project

        before_save do
          self.search_projection =
            content_builder.new(self).search_projection
        end

        after_touch :rebuild_search_projection

        define_method :rebuild_search_projection do
          builder = content_builder.new(self)
          update_column(
            :search_projection,
            builder.search_projection
          )
        end
      end
    end
  end
end
