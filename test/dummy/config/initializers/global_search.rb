# frozen_string_literal: true

SearchablePg::Global.define do |g|
  g.per_kind = 5
  g.page_size = 3
  g.authorize_with :action_policy

  g.kind :person, label: "People", icon: "i-lucide-user", prefix: "p" do |k|
    k.model Person
    k.policy false
    k.visible { |user| user&.office }
    k.title { |person| person.name }
    k.subtitle { |person| person.legal_name && "Legal name on file" }
    k.url { |person, ctx| ctx.routes.person_path(person) }
  end

  g.kind :team, label: -> { "Teams" }, icon: "i-lucide-users" do |k|
    k.model Team
    k.policy TeamPolicy
    k.title { |team| team.name }
    k.url { |team, ctx| ctx.routes.team_path(team) }
  end

  g.kind :event, label: "Events" do |k|
    k.model Event
    k.policy false
    k.relation { |events, ctx| ctx.options[:with_drafts] ? events : events.where(draft: false) }
    k.prepare { |events| events.to_h { |event| [event.id, "Event #{event.title}"] } }
    k.title { |event| event.title }
    k.subtitle { |event, ctx| ctx.prepared[event.id] }
    k.snippet { |event, ctx| SearchablePg::Global::Snippet.call(event.body, ctx.query) }
    k.url { |event, ctx| ctx.routes.event_path(event) }
    k.later { |events| events.where(past: true) }
  end
end
