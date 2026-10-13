# frozen_string_literal: true

module SearchablePg
  # Every model declared with `searchable_with ..., project: true`, so one task
  # and one job rebuild them all:
  #
  #   bin/rails searchable_pg:rebuild          # every projected model
  #   bin/rails "searchable_pg:rebuild[Person]"
  #   SearchablePg::RebuildProjectionsJob.perform_later
  module Projections
    Entry = Struct.new(:model_name, :rebuild_lock)

    @entries = {}

    class << self
      def register(model, rebuild_lock: nil)
        @entries[model.name] = Entry.new(model_name: model.name, rebuild_lock:)
      end

      # The projected models, loading the app's models first so none is missed
      # because nothing had referred to it yet.
      def models
        eager_load!
        @entries.keys.sort.map(&:constantize)
      end

      # Rebuilds every row of one model, or of every projected model, from a
      # fresh read under each model's rebuild_lock. Yields each model and its
      # count when done; returns {model => count}.
      def rebuild(model = nil)
        targets = model ? [resolve(model)] : models
        targets.to_h do |target|
          count = rebuild_model(target)
          yield target, count if block_given?
          [target, count]
        end
      end

      private

      def resolve(model)
        model = model.to_s.constantize unless model.is_a?(Class)
        eager_load!
        raise ArgumentError, "#{model} has no search projection" unless @entries.key?(model.name)
        model
      end

      def rebuild_model(model)
        lock = @entries.fetch(model.name).rebuild_lock
        count = 0
        model.unscoped.ids.each do |id|
          write = -> { model.unscoped.find_by(id:)&.rebuild_search_projection }
          lock ? lock.call(id, &write) : write.call
          count += 1
        end
        count
      end

      def eager_load!
        Rails.application.eager_load! if defined?(Rails.application) && Rails.application && !Rails.application.config.eager_load
      end
    end
  end
end
