# frozen_string_literal: true

require "test_helper"

class EndpointTest < ActionDispatch::IntegrationTest
  test "answers the envelope for 2 to 100 characters, counted by character" do
    office = User.create!(office: true)
    Team.create!(name: "Media")

    get "/search", params: {q: "  media "}, headers: {"X-User" => office.id.to_s}
    assert_response :ok
    body = response.parsed_body
    assert_equal "media", body["query"]
    assert_equal({"kind" => "team", "id" => Team.sole.id}, body["top_hit"])
    assert_equal [{"type" => "team", "label" => "Teams", "icon" => "i-lucide-users", "more" => false,
                   "results" => [{"id" => Team.sole.id, "title" => "Media", "subtitle" => nil, "url" => "/teams/#{Team.sole.id}", "snippet" => nil}]}], body["groups"]

    get "/search", params: {q: " m "}
    assert_response :unprocessable_content
    assert_equal "query must be 2 to 100 characters", response.parsed_body["error"]
    get "/search", params: {q: "é" * 100}
    assert_response :ok
    get "/search", params: {q: "é" * 101}
    assert_response :unprocessable_content
  end

  test "pages one kind" do
    office = User.create!(office: true)
    4.times { |index| Team.create!(name: "Choir #{index}") }

    get "/search", params: {q: "choir", kind: "team", page: "2"}, headers: {"X-User" => office.id.to_s}
    assert_equal ["Choir 3"], response.parsed_body["groups"].sole["results"].map { |item| item["title"] }
  end
end
