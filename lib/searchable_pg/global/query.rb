# frozen_string_literal: true

module SearchablePg
  module Global
    # Runs one query across the registry's kinds for one user.
    #
    #   Query.call(user:, query: "ada")                     # up to per_kind of each kind
    #   Query.call(user:, query: "ada", kind: :person, page: 2)  # one kind, page_size per page
    #   Query.call(user:, query: "ada", except: [:board_card])   # leave kinds out of this call
    #
    # A kind runs only when its visible check passes (a hidden kind has no
    # heading and runs no query), inside its policy scope, then the limit.
    # Kinds come back in registry order; raw scores are never compared across
    # kinds. With a statement_timeout each kind runs in its own savepoint,
    # and a kind that runs out of time is left out and marks the result
    # partial. options are handed to every block as ctx.options.
    class Query
      def self.call(...) = new(...).call

      def initialize(user:, query:, kind: nil, page: 1, except: [], options: {}, registry: Global.registry, routes: nil)
        @user = user
        @query = query.to_s
        @kind = kind&.to_s
        @page = [page.to_i, 1].max
        @except = Array(except).map(&:to_s)
        @options = options
        @registry = registry
        @routes = routes
      end

      def call
        guard!
        @partial = false
        groups = kinds.filter_map { |kind| group(kind) }
        Result.new(query: @query, top_hit: top_hit(groups), partial: @partial, groups:)
      end

      private

      def guard!
        guard = @registry.context_guard
        raise Error, "global search ran outside its required context" if guard && !guard.call
      end

      def kinds
        return [@registry.find(@kind) || raise(InvalidQuery, "unknown kind #{@kind.inspect}")] if @kind
        @registry.kinds.reject { |kind| @except.include?(kind.type) }
      end

      def group(kind)
        context = Kind::Context.new(user: @user, query: @query, routes:, options: @options)
        return unless kind.visible?(context)
        limit, offset = @kind ? [@registry.page_size, (@page - 1) * @registry.page_size] : [@registry.per_kind, 0]
        items = timed(kind.model) do
          relation = kind.matches(@registry.scope_for(@user, kind), context)
          records = relation.limit(limit + 1).offset(offset).to_a
          [kind.items(records.first(limit), context), records.size > limit]
        end
        return if items.nil?
        results, more = items
        Group.new(type: kind.type, label: kind.label, icon: kind.icon, more:, results:) if results.any?
      end

      # The first result whose title is the query, else one that starts with
      # it, earliest kind first; else the first result of the first kind.
      def top_hit(groups)
        wanted = fold(@query)
        return if wanted.empty? || groups.empty?
        pairs = groups.flat_map { |group| group.results.map { |item| [group, item] } }
        group, item = pairs.find { |_, item| fold(item.title) == wanted } ||
          pairs.find { |_, item| fold(item.title).start_with?(wanted) } ||
          pairs.first
        {kind: group.type, id: item.id}
      end

      def fold(text) = ActiveSupport::Inflector.transliterate(text.to_s).downcase.squish

      # Each kind in its own savepoint on its model's connection, so a
      # cancelled query rolls back only that kind and the timeout is restored.
      def timed(model)
        timeout = @registry.statement_timeout
        return yield unless timeout
        model.with_connection do |connection|
          connection.transaction(requires_new: true) do
            previous = connection.select_value("SHOW statement_timeout")
            connection.execute("SET LOCAL statement_timeout = #{connection.quote(timeout.to_s)}")
            result = yield
            connection.execute("SET LOCAL statement_timeout = #{connection.quote(previous)}")
            result
          end
        rescue ActiveRecord::QueryCanceled
          @partial = true
          nil
        end
      end

      def routes
        @routes ||= (defined?(Rails.application) && Rails.application) ? Rails.application.routes.url_helpers : nil
      end
    end
  end
end
