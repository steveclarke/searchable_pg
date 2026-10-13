# frozen_string_literal: true

require "test_helper"

# 135 Main's matching, from its specs (spec/models/concerns/searchable_spec.rb
# and search_content/person_spec.rb before 2026-10-11).
class EveryWordTest < ActiveSupport::TestCase
  def person(name, email: nil, phone: nil, **attributes)
    Person.create!(name:, **attributes).tap do |record|
      record.email_addresses.create!(email:) if email
      record.phone_numbers.create!(number: phone) if phone
      record.rebuild_search_projection
    end
  end

  def names(relation) = relation.map(&:name)

  test "matches word starts, near spellings and accents, best match first, then by name" do
    ["Theo Moss", "Ada Moss", "Morgan Birch", "Zoë Pike", "Ruth Ashgrove", "Ruth Lane"].each { |name| person(name) }

    assert_equal ["Ada Moss", "Theo Moss"], names(Person.search("mos"))
    assert_equal ["Ada Moss", "Theo Moss"], names(Person.search("Mosss"))
    assert_equal ["Zoë Pike"], names(Person.search("zoe"))
    assert_empty Person.search("oss")
    assert_equal ["Ruth Ashgrove"], names(Person.search("ruth ash"))
  end

  test "near spellings of long names, one letter out" do
    ["Fern Linden", "Jo Featherstonehaugh"].each { |name| person(name) }

    assert_equal ["Fern Linden"], names(Person.search("Lindon"))
    assert_equal ["Jo Featherstonehaugh"], names(Person.search("Featherstonhaugh"))
  end

  test "ranks a better match ahead of a nearer name in the alphabet" do
    exact = person("Zed Moss")
    near = person("Aaron Mose")

    assert_equal [exact, near], Person.search("moss").to_a
  end

  test "needs every word typed to match on its own, by word start or near spelling" do
    ada = person("Ada Moss")
    person("Ada Marsh")
    person("Kit Moss")

    assert_equal [ada], Person.search_names("Ada Moss").to_a
    assert_equal [ada], Person.search_names("ada mosss").to_a
    assert_equal [ada], Person.search_names("ada mo").to_a
    %w[ada.moss ada-moss ada/moss ada,moss].each { |query| assert_equal [ada], Person.search_names(query).to_a, query }
    hyphenated = person("Kit Smith-Jones")
    assert_equal [hyphenated], Person.search_names("smith-jones").to_a
    assert_equal [hyphenated], Person.search_names("jones kit").to_a
  end

  test "the whole-query scope stays public without the each-word filter" do
    person("Ada Moss")
    person("Ada Marsh")

    assert_includes names(Person.search_names_ranked("ada moss")), "Ada Marsh"
  end

  test "finds a person by a phone tail, a whole number as typed, or an email start" do
    north = person("Avery North", email: "pastoral@example.test", phone: "709-555-0142")
    person("Pat Cove", phone: "709-555-0143")
    abroad = person("Lee Tern", phone: "+1 709 555 0188")

    ["7095550188", "709-555-0188", "+1 709-555-0188", "17095550188"].each { |query| assert_equal [abroad], Person.search(query).to_a, query }
    ["0142", "5550142", "555-0142", "(709) 555-0142", "+1 709-555-0142", "7095550142", "pastoral@", "pastoral@e", "pastoral@example.test", "treasurer@"].first(9).each do |query|
      assert_equal [north], Person.search(query).to_a, query
    end
    assert_empty Person.search("treasurer@")
    assert_empty Person.search_names("0142")
    assert_empty Person.search_names("pastoral@")
    assert_equal [north], Person.search_names("north").to_a
  end

  test "keeps the relation's own conditions inside the each-word subquery" do
    person("Ada Moss")
    sample = person("Ada Mossley", sample: true)

    assert_empty Person.search_names("ada moss").where(id: sample.id)
    assert_equal ["Ada Moss", "Ada Mossley"], names(Person.including_sample.search_names("ada moss"))
    sql = queries_on("people") { Person.search_names("ada moss").to_a }.join
    assert_equal 3, sql.scan('"people"."sample" = ').size, sql
  end

  test "searches inside the current tenant only, the subquery included" do
    Org.create!(name: "North Shore Clinic", tenant: "a")
    Org.create!(name: "North Shore Clinic", tenant: "b")

    Org.with_tenant("a") do
      assert_equal 1, Org.search("north shore").count
      sql = queries_on("orgs") { Org.search("north shore").to_a }.join
      assert_equal 3, sql.scan('"orgs"."tenant" = ').size, sql
    end
  end

  test "a builder sets its own rules, and subclasses inherit them" do
    assert_equal :every_word, SearchContent::PersonName.matching
    assert_equal "simple", SearchContent::PersonName.dictionary
    assert_equal({prefix: true, dictionary: "simple"}, SearchContent::Person.using[:tsearch])
    assert_equal({word_similarity: true, threshold: 0.55, only: %i[name legal_name]}, SearchContent::Person.using[:trigram])
    assert_equal %i[name], SearchContent::PersonName.near_spelling
    assert_equal({ignoring: :accents, ranked_by: ":tsearch * 0.6 + :trigram * 0.4", order_within_rank: "people.name, people.id"}, SearchContent::PersonName.scope_options)
    assert_equal %i[title], SearchContent::Event.near_spelling
    assert_equal %i[name], SearchContent::Team.near_spelling, "unset, near spelling is the A columns"
  end
end
