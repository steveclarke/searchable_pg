# frozen_string_literal: true

# Base class for model search configuration and projection
# building. Subclasses define search fields, pg_search
# methods, and optional projection logic.
#
#   class SearchContent::Item < SearchContent::Base
#     SEARCH_FIELDS = { name: "A", description: "B" }
#     def self.search_fields = SEARCH_FIELDS
#     def self.using = { tsearch: { prefix: true } }
#
#     projection do
#       assoc(:item_type) { |it| it.display_name }
#     end
#   end
module SearchablePg
  module SearchContent
    class Base
      def initialize(record)
        @record = record
      end

      # --- Class DSL ---

      def self.projection(&block)
        @projection_block = block if block
        @projection_block
      end

      def self.search_fields
        raise NotImplementedError,
          "#{self} must implement .search_fields"
      end

      def self.using
        {
          tsearch: {
            prefix: true,
            any_word: true,
            dictionary: "english"
          },
          trigram: {
            word_similarity: true,
            threshold: 0.3
          }
        }
      end

      # --- Instance methods ---

      def search_projection
        block = self.class.projection
        return "" unless block

        @__parts = []
        instance_exec(&block)
        Array(@__parts).flatten.compact_blank.uniq.join(" ")
      end

      # --- Projection DSL methods ---

      # Include a computed method value (not a DB column)
      def compute(name)
        if record.class.column_names.include?(name.to_s)
          raise ArgumentError,
            "compute(:#{name}) is for non-DB methods; " \
            "put DB columns in SEARCH_FIELDS"
        end

        value = safe_send(record, name)
        append(value)
        value
      end

      # Iterate an association and extract tokens
      def assoc(name, &block)
        items = Array(record.public_send(name))
        return nil if items.empty?

        tokens = items.map do |item|
          instance_exec(item, &block)
        end
        append(tokens)
        tokens
      end

      # Arbitrary token generation
      def custom(&block)
        tokens = instance_exec(&block)
        append(tokens)
        tokens
      end

      private

      attr_reader :record

      def safe_send(obj, name)
        value = obj.respond_to?(name) ?
          obj.public_send(name) : nil
        value.is_a?(Array) ? value : value.to_s.presence
      end

      def append(values)
        return if values.nil?
        @__parts ||= []
        if values.is_a?(Array)
          @__parts.concat(values)
        else
          @__parts << values
        end
      end
    end
  end
end
