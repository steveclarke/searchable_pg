# frozen_string_literal: true

# Base class for model search configuration and projection
# building. Subclasses define search fields and, when they differ from the
# app's configuration, their own matching rules; optional projection logic
# fills a search_projection column with data from other rows.
#
#   class SearchContent::Item < SearchContent::Base
#     SEARCH_FIELDS = { name: "A", description: "B" }
#     def self.search_fields = SEARCH_FIELDS
#
#     projection do
#       assoc(:item_type) { |it| it.display_name }
#     end
#   end
#
#   class SearchContent::Person < SearchContent::Base
#     matching :every_word          # "Ada Moss" never finds Ada Marsh
#     near_spelling :name           # only names match near spellings
#     order_within_rank "people.name, people.id"
#     def self.search_fields = {name: "A", search_projection: "B"}
#   end
#
# Every setting is inherited by subclasses. Defining `def self.using` or
# `def self.scope_options` replaces the presets entirely, as in 0.1.
module SearchablePg
  module SearchContent
    class Base
      class_attribute :_matching, :_dictionary, :_trigram_threshold, :_near_spelling,
        :_order_within_rank, :_ranked_by, :_ignoring, instance_accessor: false, instance_predicate: false

      def initialize(record)
        @record = record
      end

      # --- Class DSL ---

      class << self
        def projection(&block)
          @projection_block = block if block
          @projection_block
        end

        def search_fields
          raise NotImplementedError,
            "#{self} must implement .search_fields"
        end

        # :any_word or :every_word; unset, the app's configured matching.
        def matching(mode = nil)
          return self._matching = Configuration.check(:matching, mode, Configuration::MATCHING) if mode
          _matching || SearchablePg.configuration.matching
        end

        # The tsearch dictionary: "english" under :any_word, "simple" (no
        # stemming, so names stay whole) under :every_word.
        def dictionary(name = nil)
          return self._dictionary = name.to_s if name
          _dictionary || ((matching == :every_word) ? "simple" : "english")
        end

        # Near-spelling threshold: the builder's, else the app's, else 0.3
        # under :any_word and 0.55 under :every_word.
        def trigram_threshold(value = nil)
          return self._trigram_threshold = value if value
          _trigram_threshold || SearchablePg.configuration.trigram_threshold || ((matching == :every_word) ? 0.55 : 0.3)
        end

        # Columns matched by near spelling as well as by word start
        # (:every_word). Unset: the columns of weight "A". Projections should
        # stay out, so "0142" finds a phone ending 0142 and not 0143.
        def near_spelling(*columns)
          return self._near_spelling = columns.flatten.map(&:to_sym) if columns.any?
          _near_spelling || weight_a_columns
        end

        # SQL ordering results of equal rank (:every_word). Unset, pg_search
        # breaks ties by id.
        def order_within_rank(sql = nil)
          return self._order_within_rank = sql if sql
          _order_within_rank
        end

        # pg_search's ranked_by (:every_word).
        def ranked_by(sql = nil)
          return self._ranked_by = sql if sql
          _ranked_by || ":tsearch * 0.6 + :trigram * 0.4"
        end

        # pg_search's ignoring (:every_word); :accents by default.
        def ignoring(value = nil)
          return self._ignoring = value if value
          _ignoring || :accents
        end

        def using
          if matching == :every_word
            {
              tsearch: {prefix: true, dictionary:},
              trigram: {word_similarity: true, threshold: trigram_threshold, only: near_spelling}
            }
          else
            {
              tsearch: {
                prefix: true,
                any_word: true,
                dictionary:
              },
              trigram: {
                word_similarity: true,
                threshold: trigram_threshold
              }
            }
          end
        end

        # Merged into pg_search_scope's options. Nothing under :any_word (0.1
        # behaviour); accents ignored, the rank and the order within it under
        # :every_word.
        def scope_options
          return {} unless matching == :every_word
          {ignoring:, ranked_by:, order_within_rank:}.compact
        end

        private

        def weight_a_columns
          fields = search_fields
          fields.is_a?(Hash) ? fields.filter_map { |column, weight| column.to_sym if weight.to_s == "A" } : []
        end
      end

      # --- Instance methods ---

      # Space-separated distinct tokens, or nil when there are none.
      def search_projection
        block = self.class.projection
        return nil unless block

        @parts = []
        instance_exec(&block)
        Array(@parts).flatten.compact_blank.uniq.join(" ").presence
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

      # Several computed values at once.
      def compute_many(*names)
        names.map { |name| compute(name) }
      end

      # Iterate an association (or the one row of a belongs_to) and extract
      # tokens
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

      # --- Helpers ---

      # Each address's street, city, province and postal code (and country).
      def project_addresses(assoc: :addresses, fields: %i[address1 address2 city province postal_code country])
        self.assoc(assoc) { |address| fields.map { |field| address.try(field) } }
      end

      def project_emails(assoc: :email_addresses, attr: :email)
        self.assoc(assoc) { |row| email_tokens(row.public_send(attr)) }
      end

      # The address whole, then its name and its domain, so "ada@e" and
      # "example.test" find it too.
      def email_tokens(email)
        email = email.to_s
        return [] if email.empty?
        [email, *email.split("@", 2)]
      end

      def project_phones(assoc: :phone_numbers, attr: :number)
        self.assoc(assoc) { |row| phone_tokens(row.public_send(attr)) }
      end

      # All the digits, the last seven, and the area code, exchange and last
      # four on their own; a North American number written with its country
      # code also gives the ten digits without it. An extension is left out.
      def phone_tokens(number)
        digits = number.to_s.split(/x|ext/i).first.to_s.gsub(/\D/, "")
        return [] if digits.empty?
        national = digits.delete_prefix("1") if digits.length == 11 && digits.start_with?("1")
        [digits, national, (digits[-7, 7] if digits.length > 7), (digits[-10, 3] if digits.length >= 10), (digits[-7, 3] if digits.length >= 7), digits[-4, 4]]
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
        @parts ||= []
        if values.is_a?(Array)
          @parts.concat(values)
        else
          @parts << values
        end
      end
    end
  end
end
