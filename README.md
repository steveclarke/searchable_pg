# searchable_pg

An opinionated layer on top of [pg_search](https://github.com/Casecommons/pg_search) that gives your ActiveRecord models a clean, consistent search interface.

You get two things:

1. A **`Searchable` concern** you include in your model
2. A **`SearchContent` builder** where you define what's searchable and how

The gem handles the wiring between them. You focus on what fields matter and how they should be weighted.

## Prerequisites

- PostgreSQL with `pg_trgm` and `unaccent` extensions enabled
- The [pg_search](https://github.com/Casecommons/pg_search) gem (pulled in automatically as a dependency)
- Rails 7.0+

Enable the required extensions in a migration:

```ruby
class EnableSearchExtensions < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pg_trgm"
    enable_extension "unaccent"
  end
end
```

## Installation

Add to your Gemfile:

```ruby
gem "searchable_pg"
```

Or from GitHub:

```ruby
gem "searchable_pg", github: "steveclarke/searchable_pg"
```

## Quick Start

### 1. Generate the search content builder

```bash
bin/rails generate searchable_pg:searchable Article title body --project
```

This creates:

- `app/models/search_content/article.rb` — the builder
- `db/migrate/..._add_search_projection_to_articles.rb` — adds a `search_projection` column + GIN index
- `lib/tasks/search/rebuild_article.rake` — backfill task
- `test/models/search_content/article_test.rb` — test file
- Injects `include Searchable` and `searchable_with` into your model

### 2. Customize the builder

The generator creates a working starting point. Open `app/models/search_content/article.rb` and adjust:

```ruby
module SearchContent
  class Article < SearchContent::Base
    SEARCH_FIELDS = {
      title: "A",
      body: "B",
      search_projection: nil
    }

    def self.search_fields = SEARCH_FIELDS

    projection do
      assoc(:tags) { |t| t.name }
      assoc(:author) { |a| a.name }
    end
  end
end
```

### 3. Migrate and backfill

```bash
bin/rails db:migrate
bin/rails search:rebuild_article
```

### 4. Search

```ruby
Article.search("postgres full text")
Article.published.search("deployment")
```

That's it. You have full-text search with typo tolerance.

## How It Works

### The Builder

Each searchable model gets a `SearchContent` builder class that defines three things:

**Search fields** — which columns to search and how important they are:

```ruby
SEARCH_FIELDS = {
  name: "A",         # Highest priority — matches here rank first
  description: "B",  # Medium priority
  notes: "C",        # Lower priority
}
```

Weights go from A (highest) to D (lowest). A match in a weight-A field ranks higher than one in weight-C.

**Search strategy** — how PostgreSQL searches the text:

```ruby
def self.using
  {
    tsearch: { prefix: true, any_word: true, dictionary: "english" },
    trigram: { word_similarity: true, threshold: 0.3 }
  }
end
```

The default uses both strategies together:
- **tsearch** — PostgreSQL's built-in full-text search. Understands English stemming ("running" matches "run"), prefix matching ("depl" matches "deployment"), and boolean logic.
- **trigram** — fuzzy matching based on character similarity. Catches typos and partial words that tsearch would miss.

These are sensible defaults. Override `using` in your builder if you need different behavior.

**Scope options** — ranking and extras:

```ruby
def self.scope_options
  {
    ignoring: :accents,                        # "cafe" matches "caf&eacute;"
    ranked_by: ":tsearch * 0.6 + :trigram * 0.4"  # weight the strategies
  }
end
```

### Projections

Sometimes you want to search a model by data that lives in its associations. A room should be findable by the names of people in it. An article should be findable by its tags.

Projections solve this by denormalizing association data into a `search_projection` text column on the model. When the record is saved, the projection is rebuilt automatically.

```ruby
projection do
  assoc(:participants) { |u| u.name }
  assoc(:tags) { |t| t.name }
  compute :formatted_code
  custom { record.metadata&.dig("keywords")&.join(" ") }
end
```

The projection DSL has three methods:

| Method | Purpose |
|--------|---------|
| `assoc(:name) { \|item\| ... }` | Extract tokens from an association |
| `compute(:method)` | Call a method on the record (must not be a DB column) |
| `custom { ... }` | Arbitrary token generation (access the record via `record`) |

To use projections, pass `project: true` when declaring search:

```ruby
class Room < ApplicationRecord
  include Searchable
  searchable_with SearchContent::Room, project: true
end
```

This adds:
- A `before_save` callback that rebuilds the projection
- An `after_touch` callback for when associations change
- A `rebuild_search_projection` instance method for manual rebuilds

For `after_touch` to fire when associations change, add `touch: true` to the relevant `belongs_to`:

```ruby
class RoomParticipant < ApplicationRecord
  belongs_to :room, touch: true
  belongs_to :user
end
```

### Without Projections

Not every model needs projections. If you're only searching direct columns, skip the `--project` flag:

```bash
bin/rails generate searchable_pg:searchable Tag name
```

```ruby
class Tag < ApplicationRecord
  include Searchable
  searchable_with SearchContent::Tag
end

Tag.search("rails")
```

No migration, no projection column, no rake task. Just the builder and the search scope.

## Generator Reference

```
bin/rails generate searchable_pg:searchable MODEL [fields...] [options]
```

**Arguments:**

| Argument | Description |
|----------|-------------|
| `MODEL` | Model name (e.g., `Article`, `User`) |
| `fields` | Optional list of searchable column names. Auto-assigned weights A, B, C, D in order. |

**Options:**

| Option | Description |
|--------|-------------|
| `--project` | Add `search_projection` column, GIN index, projection DSL, and rake task |
| `--skip-model-injection` | Don't modify the model file — you'll add `include Searchable` yourself |

**Generated files:**

| File | When |
|------|------|
| `app/models/search_content/<model>.rb` | Always |
| `test/models/search_content/<model>_test.rb` | Always |
| `db/migrate/..._add_search_projection_to_<table>.rb` | With `--project` |
| `lib/tasks/search/rebuild_<model>.rake` | With `--project` |

## Backfilling Existing Records

After adding search to a model with `--project`, existing records need their `search_projection` populated:

```bash
bin/rails search:rebuild_article
```

The generator creates a per-model rake task. For convenience, you can add an umbrella task:

```ruby
# lib/tasks/search.rake
namespace :search do
  task rebuild_all: :environment do
    Rake::Task["search:rebuild_article"].invoke
    Rake::Task["search:rebuild_room"].invoke
  end
end
```

## License

MIT
