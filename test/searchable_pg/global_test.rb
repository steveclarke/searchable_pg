# frozen_string_literal: true

require "test_helper"

class GlobalTest < ActiveSupport::TestCase
  Query = SearchablePg::Global::Query

  setup do
    @office = User.create!(office: true)
    @member = User.create!
  end

  def search(user, query, **options) = Query.call(user:, query:, **options)

  def titles(result) = result.groups.to_h { |group| [group.type, group.results.map(&:title)] }

  test "groups kinds in registry order, each inside what the user may open" do
    Person.create!(name: "Ada Moss")
    choir = Team.create!(name: "Ada's choir")
    Team.create!(name: "Ada's band")
    @member.update!(team_ids: [choir.id])
    Event.create!(title: "Ada's lunch", body: "Lunch for Ada after church. Bring a dish.")

    assert_equal({"person" => ["Ada Moss"], "team" => ["Ada's band", "Ada's choir"], "event" => ["Ada's lunch"]}, titles(search(@office, "ada")))
    assert_equal({"team" => ["Ada's choir"], "event" => ["Ada's lunch"]}, titles(search(@member, "ada")))
  end

  test "a hidden kind runs no query and has no heading" do
    Person.create!(name: "Ada Moss")

    assert_empty queries_on("people") { assert_empty search(@member, "ada moss").groups }
    assert_empty search(nil, "ada").groups
  end

  test "records the user may not open never push a visible one past the limit" do
    6.times { |index| Team.create!(name: "Hidden choir #{index}") }
    visible = Team.create!(name: "Visible choir")
    @member.update!(team_ids: [visible.id])

    assert_equal({"team" => ["Visible choir"]}, titles(search(@member, "choir")))
  end

  test "says more when a sixth match exists, never how many" do
    5.times { |index| Team.create!(name: "Choir #{index}") }
    refute search(@office, "choir").groups.sole.more
    Team.create!(name: "Choir 5")
    group = search(@office, "choir").groups.sole
    assert group.more
    assert_equal 5, group.results.size
  end

  test "pages one kind for a see-all page" do
    7.times { |index| Team.create!(name: "Choir #{index}") }

    first = search(@office, "choir", kind: :team).groups.sole
    assert_equal ["Choir 0", "Choir 1", "Choir 2"], first.results.map(&:title)
    assert first.more
    last = search(@office, "choir", kind: "team", page: 3).groups.sole
    assert_equal ["Choir 6"], last.results.map(&:title)
    refute last.more
    assert_raises(SearchablePg::Global::InvalidQuery) { search(@office, "choir", kind: :nothing) }
  end

  test "picks the top hit: an exact title, else a title starting with the query, else the first result" do
    Team.create!(name: "Media")
    Event.create!(title: "Media night")
    assert_equal "Media", lookup(search(@office, "media"))
    assert_equal "Media night", lookup(search(@office, "media n"))
    Event.create!(title: "Easter at the media desk")
    assert_equal "Easter at the media desk", lookup(search(@office, "desk"))
    assert_nil search(@office, "zzzz").top_hit
  end

  def lookup(result)
    hit = result.top_hit
    result.groups.find { |group| group.type == hit[:kind] }.results.find { |item| item.id == hit[:id] }.title
  end

  test "hands each kind its call's options, prepared values and snippets" do
    Event.create!(title: "Ada's lunch", body: "Lunch after church. Bring <b>a dish</b> for Ada.")
    Event.create!(title: "Ada's draft", draft: true)

    item = search(@office, "ada").groups.find { |group| group.type == "event" }.results.sole
    assert_equal "Event Ada's lunch", item.subtitle
    assert_equal "Bring &lt;b&gt;a dish&lt;/b&gt; for <mark>Ada</mark>.", item.snippet
    assert_equal "/events/#{Event.find_by!(title: "Ada's lunch").id}", item.url
    assert_equal 2, search(@office, "ada", options: {with_drafts: true}).groups.find { |group| group.type == "event" }.results.size
    assert_empty search(@office, "ada", except: [:event]).groups
  end

  test "sorts a kind's later rows last" do
    Event.create!(title: "Choir concert", past: true)
    Event.create!(title: "Choir practice")

    assert_equal ["Choir practice", "Choir concert"], search(@office, "choir").groups.sole.results.map(&:title)
  end

  test "leaves out a kind that runs out of time and marks the result partial" do
    Team.create!(name: "Choir")
    Event.create!(title: "Choir practice")
    registry = SearchablePg::Global::Registry.build do |g|
      g.statement_timeout = "50ms"
      g.kind :slow, label: "Slow" do |k|
        k.model Team
        k.policy false
        k.search { |teams| teams.where("pg_sleep(0.2) IS NOT NULL") }
        k.title(&:name)
      end
      g.kind :event, label: "Events" do |k|
        k.model Event
        k.policy false
        k.title(&:title)
      end
    end

    result = Query.call(user: @office, query: "choir", registry:)
    assert result.partial
    assert_equal ["event"], result.groups.map(&:type)
    assert_equal "0", ActiveRecord::Base.lease_connection.select_value("SHOW statement_timeout")
  end

  test "runs Pundit scopes and refuses to run outside a required context" do
    Event.create!(title: "Choir practice")
    Event.create!(title: "Choir draft", draft: true)
    tenant = nil
    registry = SearchablePg::Global::Registry.build do |g|
      g.authorize_with :pundit
      g.require_context { tenant }
      g.kind :event, label: "Events" do |k|
        k.model Event
        k.policy EventPolicy
        k.title(&:title)
      end
    end

    assert_raises(SearchablePg::Global::Error) { Query.call(user: @office, query: "choir", registry:) }
    tenant = "a"
    assert_equal ["Choir practice"], Query.call(user: @office, query: "choir", registry:).groups.sole.results.map(&:title)
  end

  test "refuses a kind without a model, a title or a policy decision" do
    assert_raises(SearchablePg::Global::Error) { SearchablePg::Global::Registry.build { |g| g.kind(:team, label: "Teams") { |k| k.model Team } } }
    assert_raises(SearchablePg::Global::Error) {
      SearchablePg::Global::Registry.build { |g|
        g.kind(:team, label: "Teams") { |k|
          k.model Team
          k.policy false
        }
      }
    }
    assert_raises(SearchablePg::Global::Error) {
      SearchablePg::Global::Registry.build { |g|
        g.kind(:team, label: "Teams") { |k|
          k.model Team
          k.title(&:name)
        }
      }
    }
  end

  test "envelope carries only the declared fields" do
    Person.create!(name: "Ada Moss", legal_name: "Adelaide Moss").phone_numbers.create!(number: "709-555-0142")
    envelope = search(@office, "ada").to_h

    assert_equal %i[query top_hit partial groups], envelope.keys
    assert_equal %i[type label icon more results], envelope[:groups].first.keys
    assert_equal %i[id title subtitle url snippet], envelope[:groups].first[:results].first.keys
    refute_includes envelope.to_json, "0142"
    refute_includes envelope.to_json, "Adelaide"
  end

  test "passes a lambda the arguments it declares" do
    kind = SearchablePg::Global::Kind.new(:x, label: "X")
    seen = []
    [->(a) { seen << [a] }, ->(a, b = nil) { seen << [a, b] }, ->(*all) { seen << all }, proc { |a, b| seen << [a, b] }].each { |block| kind.send(:invoke, block, 1, 2) }
    assert_equal [[1], [1, 2], [1, 2], [1, 2]], seen
    assert_equal "Choir", kind.send(:invoke, :name.to_proc, Team.new(name: "Choir"), :ctx)
  end
end
