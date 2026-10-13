# frozen_string_literal: true

require "test_helper"

class BaseTest < ActiveSupport::TestCase
  def builder(record = Person.new) = SearchablePg::SearchContent::Base.new(record)

  test "splits a phone into the digits, the last seven, and its area code, exchange and last four" do
    assert_equal ["7095550142", nil, "5550142", "709", "555", "0142"], builder.phone_tokens("(709) 555-0142 x12")
    assert_equal ["17095550142", "7095550142", "5550142", "709", "555", "0142"], builder.phone_tokens("+1 709 555 0142")
    assert_equal ["5550142", nil, nil, nil, "555", "0142"], builder.phone_tokens("555-0142")
    assert_equal ["0142", nil, nil, nil, nil, "0142"], builder.phone_tokens("0142")
    assert_equal [], builder.phone_tokens("")
  end

  test "gives an email whole, then its name and domain" do
    assert_equal ["ada@example.test", "ada", "example.test"], builder.email_tokens("ada@example.test")
    assert_equal [], builder.email_tokens(nil)
  end

  test "projects nothing as nil" do
    assert_nil SearchContent::Person.new(Person.new).search_projection
    assert_nil SearchContent::Team.new(Team.new).search_projection
  end

  test "projects with compute, compute_many, custom and addresses" do
    address = Struct.new(:address1, :address2, :city, :province, :postal_code, :country)
    record = Struct.new(:nickname, :initials, :addresses, :tags) do
      def self.column_names = %w[name]
    end.new("Ada", "AM", [address.new("1 Hill Rd", nil, "Springdale", "NL", "A0A 1B0", "CA")], %w[choir])
    klass = Class.new(SearchablePg::SearchContent::Base) do
      projection do
        compute_many :nickname, :initials
        project_addresses
        custom { record.tags }
      end
    end

    assert_equal "Ada AM 1 Hill Rd Springdale NL A0A 1B0 CA choir", klass.new(record).search_projection
    assert_raises(ArgumentError) { Class.new(SearchablePg::SearchContent::Base) { projection { compute :name } }.new(record).search_projection }
  end

  test "a builder that is not a Base still works, with the app's matching" do
    duck = Class.new do
      def self.search_fields = %i[name]
      def self.using = {tsearch: {prefix: true}}
      def self.scope_options = {order_within_rank: "teams.id"}
    end
    model = Class.new(ApplicationRecord) do
      self.table_name = "teams"
      def self.name = "DuckTeam"
      include Searchable
    end
    with_configuration(matching: :every_word) { model.searchable_with(duck) }
    model.create!(name: "Media Team")
    model.create!(name: "Media Arts")

    assert_equal ["Media Team"], model.search("media team").map(&:name)
    assert_respond_to model, :search_ranked
  end

  test "refuses a builder without search_fields and using" do
    assert_raises(ArgumentError) { Team.searchable_with(Object) }
  end
end
