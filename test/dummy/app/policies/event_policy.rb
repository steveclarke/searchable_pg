# frozen_string_literal: true

# Pundit: everyone sees published events.
class EventPolicy
  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve = @scope.where(draft: false)
  end
end
