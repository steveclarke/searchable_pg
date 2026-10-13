# frozen_string_literal: true

require "test_helper"

class NormalizeTest < ActiveSupport::TestCase
  test "searches phone numbers typed with punctuation as their separate numbers" do
    {
      "(709) 555-0142" => "709 555 0142",
      " 555.0142 " => "555 0142",
      "Featherstonehaugh-Wick" => "Featherstonehaugh Wick",
      "+1 709-555-0142" => "709 555 0142",
      "+17095550142" => "7095550142",
      "1-709-555-0142" => "709 555 0142",
      "+44 20 7946 0958" => "44 20 7946 0958",
      "jo.2@example.test" => "jo.2@example.test",
      nil => ""
    }.each { |query, expected| assert_equal expected, SearchablePg.normalize(query), query.inspect }
    assert_equal "709 555 0142", Searchable.normalize("(709) 555-0142")
  end
end
