# searchable_pg

An opinionated layer on top of [pg_search](https://github.com/Casecommons/pg_search) that gives ActiveRecord models a clean, consistent search interface, and, as an opt-in part, one global search box across every kind of record a person may open.

- A **`Searchable` concern** included in each model.
- A **`SearchContent` builder** per search: which columns, their weights, the matching rules and an optional projection of data from other rows.
- **Global search** (opt-in): a registry of kinds, a permission-checked query runner, a JSON envelope and command palette helpers for Nuxt UI.

Each builder sets its own matching rules. The defaults are 0.1.0's, so an app that upgrades sees no change until it chooses one.

## Prerequisites

- Ruby 3.3+, Rails 8.0+, PostgreSQL 16+ with the `pg_trgm` and `unaccent` extensions
- [pg_search](https://github.com/Casecommons/pg_search) 2.3.7+ (a dependency)

```ruby
class EnableSearchExtensions < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm"
    enable_extension "unaccent"
  end
end
```

## Installation

Apps pin a released version:

```ruby
gem "searchable_pg", github: "steveclarke/searchable_pg", tag: "v0.2.0"
```

Then write the settings file, which spells out today's defaults so a later default never moves an app's results:

```bash
bin/rails generate searchable_pg:install
```

```ruby
# config/initializers/searchable_pg.rb
SearchablePg.configure do |c|
  c.matching = :any_word            # or :every_word
  c.projection_rebuild = :callbacks # or :manual
end
```

Settings are read while models load and frozen once the app has booted. A model loaded by an initializer that runs before `searchable_pg.rb` would build its scopes on the defaults, so no earlier initializer refers to a searchable model.

## Quick start

```bash
bin/rails generate searchable_pg:searchable Article title body --project
bin/rails db:migrate
bin/rails searchable_pg:rebuild
```

The generator writes:

- `app/models/search_content/article.rb`: the builder
- `db/migrate/..._add_search_projection_to_articles.rb` (with `--project`): a `search_projection` column and its GIN index
- `test/models/search_content/article_test.rb` or `spec/models/search_content/article_spec.rb`, matching the app
- `include Searchable` and `searchable_with` in the model (unless `--skip-model-injection`)

```ruby
Article.search("postgres full text")
Article.published.search("deployment")
```

## Builders

```ruby
module SearchContent
  class Person < SearchContent::Base
    matching :every_word                 # every word typed must match
    near_spelling :name, :legal_name     # only names match near spellings
    order_within_rank "people.name, people.id"

    def self.search_fields = {name: "A", legal_name: "A", search_projection: "B"}

    projection do
      project_emails
      project_phones
    end
  end
end

class Person < ApplicationRecord
  include Searchable
  searchable_with SearchContent::Person, project: true
  searchable_with SearchContent::PersonName, scope: :search_names  # a second, name-only scope
end
```

Search fields name the columns and weights, A (highest) to D: a hash, or an array for unweighted columns.

### Matching

| | `:any_word` (default) | `:every_word` |
|---|---|---|
| Several words | one is enough | the whole query ranks; each word must also match on its own |
| tsearch | prefix, `any_word`, dictionary `english` | prefix, dictionary `simple` |
| Near spelling (trigram) | every field, threshold 0.3 | `near_spelling` columns only, threshold 0.55 |
| Query | as typed | `SearchablePg.normalize`: punctuation to spaces, leading `+` and country code `1` dropped |
| Ranking | pg_search's | `:tsearch * 0.6 + :trigram * 0.4`, accents ignored, then `order_within_rank` |
| Suits | broad lists, "similar" candidates | names and titles, where a wrong match is worse than none |

With `:every_word`, "Ada Moss" finds Ada Moss and never Ada Marsh or Kit Moss; "(709) 555-0142" searches as its three numbers; "Lindon" still finds Linden. The each-word subquery runs on the relation the search was called on, so a tenant scope, a default scope and the caller's own conditions hold inside it. The whole-query scope stays public as `search_ranked` (or `"#{scope}_ranked"`).

### Builder settings

Each is a class method, inherited by subclasses. Unset, it falls back to the app's configuration, then to the matching mode's preset.

| Setting | Does |
|---|---|
| `matching :any_word` or `:every_word` | how several words are read |
| `dictionary :simple` | the tsearch dictionary |
| `trigram_threshold 0.4` | near-spelling threshold |
| `near_spelling :name` | columns that match near spellings (`:every_word`; unset: the weight-A columns) |
| `order_within_rank "people.name"` | SQL order for equal rank (`:every_word`; unset: by id) |
| `ranked_by "..."` | pg_search's `ranked_by` (`:every_word`) |
| `ignoring :accents` | pg_search's `ignoring` (`:every_word`) |

Defining `def self.using` or `def self.scope_options` replaces the presets entirely, as in 0.1. A builder need not inherit from `SearchContent::Base`: anything answering `.search_fields` and `.using` works, and may answer `.matching`.

## Projections

A `search_projection` text column holds data from other rows (emails, phone digits, members' names), so a record is found by it.

```ruby
projection do
  assoc(:tags) { |tag| tag.name }
  compute :formatted_code            # a method, not a column
  compute_many :initials, :nickname
  custom { record.keywords }
  project_emails                     # whole address, its name and its domain
  project_phones                     # digits, last seven, area code, exchange, last four
  project_addresses
end
```

An empty projection is stored as `nil`.

| `rebuild:` on `searchable_with ..., project: true` | Does |
|---|---|
| `:callbacks` (default) | rebuilt in `before_save` and `after_touch`; children's `belongs_to` take `touch: true` |
| `:manual` | no callbacks; the app calls `rebuild_search_projection` where its inputs change. Each rebuild reads a fresh copy of the record and writes with `update_column` (no callbacks, no audit version) |

`rebuild_lock: ->(id, &write) { MyLocks.transaction(id, &write) }` wraps each write of a full rebuild, so it cannot race the app's own edits.

Every projected model is registered, so one task and one job rebuild them all:

```bash
bin/rails searchable_pg:rebuild            # every projected model
bin/rails "searchable_pg:rebuild[Person]"
```

```ruby
SearchablePg::RebuildProjectionsJob.perform_later
```

## Global search (opt-in)

One query across every kind of record a person may open, grouped by kind. Nothing is global by default, and `SearchablePg::Global` loads only when an app refers to it. The gem mounts no route: the app owns its controller, page and command bar.

```bash
bin/rails generate searchable_pg:global --policies=action_policy   # or pundit
bin/rails generate searchable_pg:global_frontend --path=app/frontend/lib/global-search
```

### Registry

```ruby
# config/initializers/global_search.rb
SearchablePg::Global.define do |g|
  g.per_kind = 5
  g.page_size = 25
  g.statement_timeout = "500ms"
  g.authorize_with :action_policy                    # :pundit, or ->(user, model, policy) { relation }
  g.require_context { ActsAsTenant.current_tenant }  # optional: raises when nil

  g.kind :event, label: "Events", icon: "i-lucide-calendar", prefix: "e" do |k|
    k.model Event
    k.policy EventPolicy                     # or `policy false` when visible alone decides
    k.visible { |user| user.member? }        # false: no query, no heading
    k.scope :search                          # which searchable_with scope matches
    k.relation { |events, ctx| events.where(cancelled: false) }
    k.includes :venue
    k.prepare { |events, ctx| Event.next_dates(events) }   # once per page of results
    k.title { |event| event.title }
    k.subtitle { |event, ctx| ctx.prepared[event.id] }
    k.url { |event, ctx| ctx.routes.event_path(event) }
    k.snippet { |event, ctx| SearchablePg::Global::Snippet.call(event.body, ctx.query) }
    k.later { |events| events.where(ended: true) }         # these sort last
  end
end
```

- The block runs on first use and again after each code reload, so it names models and policies directly.
- Each kind's policy scope narrows the rows before the search and the limit: records the user may not open never push visible ones out.
- `title`, `subtitle`, `url` and `snippet` are the only values that leave the server. A snippet is escaped HTML whose only tag is `<mark>`.
- `k.search { |relation, ctx| ... }` replaces `relation.public_send(scope, ctx.query)` when the matching lives elsewhere.
- Blocks receive `ctx` with `user`, `query`, `routes`, `prepared` and the call's `options`; a block may leave out arguments it does not use.

### Query

```ruby
SearchablePg::Global::Query.call(user:, query: "ada")                       # up to per_kind of each kind
SearchablePg::Global::Query.call(user:, query: "ada", kind: :event, page: 2) # one kind, page_size per page
SearchablePg::Global::Query.call(user:, query: "ada", except: [:board_card], options: {surface: :agent})
```

- Kinds come back in registry order; scores are never compared across kinds.
- Top hit: the first result whose title is the query, else one that starts with it (earliest kind first), else the first result of the first kind.
- With `statement_timeout`, each kind runs in its own savepoint; a kind that runs out of time is left out and the result is `partial`.

### Envelope

```json
{
  "query": "ada",
  "top_hit": {"kind": "person", "id": 12},
  "partial": false,
  "groups": [
    {"type": "person", "label": "People", "icon": "i-lucide-user", "more": true,
     "results": [{"id": 12, "title": "Ada Moss", "subtitle": "Moss household", "url": "/people/12", "snippet": null}]}
  ]
}
```

`more` says a further match exists; there is never a count.

### Endpoint

```ruby
class SearchController < ApplicationController
  include SearchablePg::Global::Endpoint

  def index
    render json: search_envelope(user: current_user, query: params[:q], kind: params[:kind], page: params[:page])
  rescue SearchablePg::Global::InvalidQuery => error
    render json: {error: error.message}, status: :unprocessable_content
  end
end
```

The query is squished and must be 2 to 100 characters, counted by character.

### Frontend

`searchable_pg:global_frontend` copies three TypeScript files, each naming the gem version it came from; re-running it after an upgrade shows what changed.

| File | Does |
|---|---|
| `searchGroups.ts` | envelope to Nuxt UI `CommandPaletteGroup[]`: top hit first, one group per kind, "See all" when `more` |
| `useRemoteSearch.ts` | search as you type: 200 ms debounce, abort, loading and failed states, injected fetch |
| `useRecentItems.ts` | the last 8 items opened and last 5 queries in `localStorage` under `search:recent:<user id>`; `clear()` on sign-out |

## Testing helpers

```ruby
require "searchable_pg/testing/rspec"     # or "searchable_pg/testing/minitest"

expect(Person).to find_by_search("ada moss", ada)
expect(Person).not_to find_by_search("ada moss", kit)
expect(Person).to find_by_search("moss", ada, kit).exactly
expect(Person).to find_by_search("north", ada).in_scope(:search_names)
expect(SearchablePg::Global.registry).to have_no_private_search_matches(private: {Person => %i[phone email]})
```

Minitest (`include SearchablePg::Testing::Assertions`): `assert_finds`, `refute_finds`, `assert_no_private_matches`, `assert_no_leaks(result, "CANARY")`.

## Constants

`SearchablePg::Searchable` and `SearchablePg::SearchContent::Base` are canonical; `::Searchable` and `::SearchContent::Base` are aliases defined at require time. An app's own `app/models/concerns/searchable.rb` shadows the gem's, so an app moving from a copy removes it in the same commit. `require: ["searchable_pg/no_aliases", "searchable_pg"]` in the Gemfile leaves the aliases out.

## Versions

SemVer from 0.2.0. A default changes only in a major release, after a deprecation warning in the minor before. [CHANGELOG.md](CHANGELOG.md) lists every release; [UPGRADING.md](UPGRADING.md) gives the steps.

## Development

```bash
docker run -d --name searchable-pg-postgres -e POSTGRES_PASSWORD=nitro -p 127.0.0.1:54329:5432 postgres:18
bundle install
bundle exec rake test                                   # DATABASE_URL overrides the database
RAILS_VERSION=8.0 bundle update && bundle exec rake test
```

Tests run against real PostgreSQL through a dummy Rails app (`test/dummy`). `test/fixtures/any_word_golden.json` holds 0.1.0's results on a fixed corpus; `test/fixtures/record_any_word_golden.rb` records it from any version's `lib`.

## License

MIT
