# frozen_string_literal: true

module SearchablePg
  module Global
    # The app's kinds, in display order, and the settings they share.
    class Registry
      attr_accessor :per_kind, :page_size, :statement_timeout
      attr_reader :kinds, :context_guard

      def self.build
        registry = new
        yield registry
        registry.finish!
      end

      def initialize
        @per_kind = 5
        @page_size = 25
        @statement_timeout = nil
        @kinds = []
        @authorizer = nil
      end

      # :action_policy, :pundit, or ->(user, model, policy) { relation }.
      def authorize_with(adapter = nil, &block)
        @authorizer = PolicyAdapters.resolve(block || adapter)
      end

      # Raised unless the block returns something (Unio: the current tenant),
      # so a search never runs outside it.
      def require_context(&block)
        @context_guard = block
      end

      def kind(type, label:, icon: nil, prefix: nil, &block)
        kind = Kind.new(type, label:, icon:, prefix:)
        block&.call(kind)
        raise Error, "global search kind :#{type} is declared twice" if @kinds.any? { |existing| existing.type == kind.type }
        @kinds << kind
        kind
      end

      def find(type) = @kinds.find { |kind| kind.type == type.to_s }

      def scope_for(user, kind)
        policy = kind.policy_class
        return kind.model.all unless policy
        raise Error, "global search kind :#{kind.type} has a policy but the registry has no authorize_with" unless @authorizer
        @authorizer.call(user, kind.model, policy)
      end

      def finish!
        raise Error, "global search defines no kinds" if @kinds.empty?
        @kinds.each(&:validate!)
        @kinds.freeze
        freeze
      end
    end
  end
end
