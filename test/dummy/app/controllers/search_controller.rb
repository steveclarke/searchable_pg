# frozen_string_literal: true

class SearchController < ActionController::API
  include SearchablePg::Global::Endpoint

  def index
    user = User.find_by(id: request.headers["X-User"])
    render json: search_envelope(user:, query: params[:q], kind: params[:kind], page: params[:page])
  rescue SearchablePg::Global::InvalidQuery => error
    render json: {error: error.message}, status: :unprocessable_content
  end
end
