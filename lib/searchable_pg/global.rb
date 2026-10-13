# frozen_string_literal: true

require_relative "global/envelope"
require_relative "global/kind"
require_relative "global/registry"
require_relative "global/policy_adapters"
require_relative "global/snippet"
require_relative "global/query"
require_relative "global/endpoint"

module SearchablePg
  # Global search: one query across every kind of record a person may open,
  # grouped by kind. Opt-in at two levels: a model opts into search with
  # searchable_with; a kind opts into global search with a line in the app's
  # registry. Nothing is global by default, and this file loads only when an
  # app refers to SearchablePg::Global.
  #
  #   # config/initializers/global_search.rb
  #   SearchablePg::Global.define do |g|
  #     g.per_kind = 5
  #     g.authorize_with :action_policy
  #     g.kind :team, label: "Teams" do |k|
  #       k.model Team
  #       k.policy TeamPolicy
  #       k.title { |team| team.name }
  #       k.url { |team, ctx| ctx.routes.team_path(team) }
  #     end
  #   end
  #
  #   SearchablePg::Global::Query.call(user: current_user, query: "ada")
  #
  # The block runs on first use and again after each code reload, so it may
  # name the app's models and policies directly.
  module Global
    class Error < StandardError; end

    # A query outside the 2 to 100 character rule.
    class InvalidQuery < Error; end

    class << self
      def define(&block)
        @definition = block
        @registry = nil
      end

      def registry
        @registry ||= begin
          raise Error, "no global search is defined; call SearchablePg::Global.define in an initializer" unless @definition
          Registry.build(&@definition)
        end
      end

      # Rebuilt from the definition on next use (after a code reload).
      def reset!
        @registry = nil
      end
    end
  end
end
