# frozen_string_literal: true

module SearchablePg
  module Global
    # How a kind's policy narrows its model to what the user may open. The
    # scope is applied before the search and before the limit, so records the
    # user may not open never push visible ones out.
    module PolicyAdapters
      ACTION_POLICY = ->(user, model, policy) { policy.new(user:).apply_scope(model.all, type: :active_record_relation) }
      PUNDIT = ->(user, model, policy) { policy::Scope.new(user, model.all).resolve }

      def self.resolve(adapter)
        case adapter
        when :action_policy then ACTION_POLICY
        when :pundit then PUNDIT
        when Proc then adapter
        else raise ArgumentError, "authorize_with takes :action_policy, :pundit or a block, not #{adapter.inspect}"
        end
      end
    end
  end
end
