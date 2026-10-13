# frozen_string_literal: true

# Provides full-text search capabilities to ActiveRecord
# models using PostgreSQL's text search via pg_search.
#
# Accepts a SearchContent builder class that defines fields,
# weights, matching and search method. Optionally manages a
# search_projection column for associated-data search.
#
#   class Item < ApplicationRecord
#     include Searchable
#     searchable_with SearchContent::Item, project: true
#     searchable_with SearchContent::ItemName, scope: :search_names
#   end
#
# The builder's matching decides how several words are read:
#
# - :any_word: one pg_search scope; one word of the query is enough.
# - :every_word: the query is normalized (SearchablePg.normalize) and the whole
#   of it ranks; with several words, each must also match on its own, because
#   pg_search compares a near spelling with the whole query and one close word
#   would carry the rest ("Ada Moss" finding Ada Marsh). The whole-query scope
#   stays public as :"#{scope}_ranked".
#
# A builder that is not a SearchContent::Base (anything answering
# .search_fields and .using) may answer .matching; otherwise the app's
# configured matching applies.
module SearchablePg
  module Searchable
    extend ActiveSupport::Concern

    # The one-word scopes of the each-word filter: the relation the search was
    # called on, so a tenant or default scope and the caller's own conditions
    # hold inside the subquery as well.
    def self.each_word(relation, ranked, words)
      words.reduce(relation.public_send(ranked, words.join(" "))) do |matched, word|
        own = relation.unscope(:order, :limit, :offset, :select, :includes, :preload, :eager_load)
        matched.where(id: own.public_send(ranked, word).reorder(nil).select(:id))
      end
    end

    def self.matching_for(builder)
      mode = builder.respond_to?(:matching) ? builder.matching : SearchablePg.configuration.matching
      Configuration.check(:matching, mode, Configuration::MATCHING)
    end

    # Callers using the top-level alias keep `Searchable.normalize`.
    def self.normalize(query) = SearchablePg.normalize(query)

    class_methods do
      # scope: the scope's name (several builders may serve one model).
      # project: keep a search_projection column (see SearchContent::Base.projection).
      # rebuild: :callbacks or :manual (default: the configured projection_rebuild).
      # rebuild_lock: ->(id, &write) { ... } wraps each write of a full rebuild
      #   (SearchablePg::Projections.rebuild), so it cannot race the app's own
      #   edits; it must call the block.
      def searchable_with(content_builder, scope: :search, project: false, rebuild: nil, rebuild_lock: nil)
        unless content_builder.respond_to?(:search_fields) &&
            content_builder.respond_to?(:using)
          raise ArgumentError,
            "builder must respond to .search_fields/.using"
        end

        include PgSearch::Model unless include?(PgSearch::Model)
        # Which builder serves each scope, for SearchablePg::Testing.
        class_attribute :searchable_pg_builders, instance_accessor: false, default: {} unless respond_to?(:searchable_pg_builders)
        self.searchable_pg_builders = searchable_pg_builders.merge(scope.to_sym => content_builder)

        options = {
          against: content_builder.search_fields,
          using: content_builder.using
        }
        if content_builder.respond_to?(:scope_options)
          options.merge!(content_builder.scope_options)
        end

        if Searchable.matching_for(content_builder) == :every_word
          ranked = :"#{scope}_ranked"
          pg_search_scope ranked, options
          scope scope, ->(query) {
            words = SearchablePg.normalize(query).split
            (words.size > 1) ? Searchable.each_word(all, ranked, words) : public_send(ranked, words.join(" "))
          }
        else
          pg_search_scope scope, options
        end

        return unless project

        rebuild ||= SearchablePg.configuration.projection_rebuild
        Configuration.check(:rebuild, rebuild, Configuration::PROJECTION_REBUILD)
        if rebuild_lock && !rebuild_lock.respond_to?(:call)
          raise ArgumentError, "rebuild_lock must be callable"
        end
        Projections.register(self, rebuild_lock:)

        if rebuild == :callbacks
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
        else
          # Built from a fresh copy, so this record's loaded associations stay
          # as they were and a stale one never writes an old projection.
          # update_column: no callbacks, no audit version.
          define_method :rebuild_search_projection do
            fresh = self.class.unscoped.find(id)
            update_column(:search_projection, content_builder.new(fresh).search_projection)
          end
        end
      end
    end
  end
end
