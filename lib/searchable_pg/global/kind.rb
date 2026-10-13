# frozen_string_literal: true

module SearchablePg
  module Global
    # One kind of record in global search, declared in the registry.
    #
    #   g.kind :event, label: "Events", icon: "i-lucide-calendar", prefix: "e" do |k|
    #     k.model Event
    #     k.policy CalendarPolicy           # its scope narrows the rows first
    #     k.visible { |user| CalendarPolicy.new(user:).apply(:access?) }
    #     k.scope :search                   # the searchable_with scope that matches
    #     k.relation { |rel, ctx| rel.where(archived_at: nil) }
    #     k.includes :venue
    #     k.prepare { |events, ctx| Event.next_dates(events) }  # once per page of results
    #     k.title { |event| event.title }
    #     k.subtitle { |event, ctx| ctx.prepared[event.id] }
    #     k.url { |event, ctx| ctx.routes.event_path(event) }
    #     k.snippet { |event, ctx| SearchablePg::Global::Snippet.call(event.body, ctx.query) }
    #     k.later { |rel| rel.where(ended: true) } # these sort after the rest
    #   end
    #
    # Every block receives the record (or relation) and a Context with user,
    # query, routes, prepared and the call's options. A block that ignores its
    # arguments may leave them out.
    #
    # policy is required: a policy class for the registry's adapter, or
    # `policy false` when visible alone decides who may search the kind.
    # search replaces `relation.public_send(scope, query)` when the matching
    # lives elsewhere: `k.search { |rel, ctx| People.search(rel, ctx.query) }`.
    class Kind
      Context = Struct.new(:user, :query, :routes, :options, :prepared)

      attr_reader :type, :icon, :prefix

      def initialize(type, label:, icon: nil, prefix: nil)
        @type = type.to_s
        @label = label
        @icon = icon
        @prefix = prefix
        @scope = :search
        @policy = :unset
        @includes = []
      end

      # --- DSL ---

      def model(klass = nil) = klass ? (@model = klass) : @model

      def policy(klass)
        @policy = klass
        self
      end

      def scope(name) = @scope = name.to_sym
      def includes(*associations) = @includes.concat(associations.flatten)

      %i[visible relation search prepare title subtitle url snippet later].each do |name|
        define_method(name) { |&block| instance_variable_set(:"@#{name}", block) }
      end

      # --- Used by Query ---

      def label = @label.respond_to?(:call) ? @label.call : @label

      def scope_name = @scope

      def policy_class
        raise Error, "global search kind :#{type} needs a policy (or `policy false` when visible alone decides)" if @policy == :unset
        @policy || nil
      end

      def validate!
        raise Error, "global search kind :#{type} needs a model" unless @model
        raise Error, "global search kind :#{type} needs a title" unless @title
        policy_class
        self
      end

      def visible?(context) = @visible ? !!invoke(@visible, context.user, context) : true

      # The rows the user may open, matched, best match first, then `later`
      # rows last.
      def matches(base, context)
        base = invoke(@relation, base, context) if @relation
        matched = @search ? invoke(@search, base, context) : base.public_send(@scope, context.query)
        matched = matched.includes(*@includes) if @includes.any?
        return matched unless @later
        model = matched.klass
        later = invoke(@later, base, context).select(model.primary_key)
        matched.reorder(Arel::Nodes::Grouping.new(model.arel_table[model.primary_key].in(later.arel))).order(*matched.order_values)
      end

      def items(records, context)
        context.prepared = @prepare && invoke(@prepare, records, context)
        records.map do |record|
          Item.new(
            id: record.id,
            title: invoke(@title, record, context),
            subtitle: @subtitle && invoke(@subtitle, record, context),
            url: @url && invoke(@url, record, context),
            snippet: @snippet && invoke(@snippet, record, context)
          )
        end
      end

      private

      # A block takes what it names; a lambda (or &:title) only as many
      # arguments as it requires.
      def invoke(block, *args)
        return block.call(*args) unless block.lambda?
        block.call(*args.first((block.arity >= 0) ? block.arity : -block.arity - 1))
      end
    end
  end
end
