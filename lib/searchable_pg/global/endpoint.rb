# frozen_string_literal: true

module SearchablePg
  module Global
    # For the app's own search controller (the gem mounts no route).
    #
    #   class SearchController < ApplicationController
    #     include SearchablePg::Global::Endpoint
    #
    #     def index
    #       render json: search_envelope(user: current_user, query: params[:q], kind: params[:kind], page: params[:page])
    #     rescue SearchablePg::Global::InvalidQuery => error
    #       render json: {error: error.message}, status: :unprocessable_content
    #     end
    #   end
    module Endpoint
      MIN = 2
      MAX = 100

      # The query squished; 2 to 100 characters, counted by character.
      def self.query!(query)
        query = query.to_s.squish
        raise InvalidQuery, "query must be #{MIN} to #{MAX} characters" unless query.length.between?(MIN, MAX)
        query
      end

      def search_envelope(user:, query:, kind: nil, page: nil, **options)
        Query.call(user:, query: Endpoint.query!(query), kind: kind.presence, page: page || 1, **options).to_h
      end
    end
  end
end
