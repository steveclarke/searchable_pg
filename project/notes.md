# searchable_pg — Gem Extraction Notes

## What This Is

An opinionated layer on top of the `pg_search` gem that provides:

1. A **`Searchable` concern** — `include Searchable` in any ActiveRecord model to get a `.search(query)` scope powered by PostgreSQL's tsearch + trigram matching
2. A **`SearchContent::Base` builder** — clean DSL for defining search fields, weights, ranking, and denormalized projections for association data
3. A **Rails generator** — `bin/rails generate searchable_pg:searchable ModelName field1 field2 --project` scaffolds everything

## Origin Story

Steve built this pattern originally in **NinjaNizer** (an inventory management app), then ported it to **Unio** (where the generator was added), then to **Outport** (where it was refined with namespaced generators and dynamic migration versions). It's now proven across three production apps and ready to be a standalone gem.

## Reference Implementations

All three are on Steve's machine. The code is nearly identical — diff them to see the evolution.

### NinjaNizer (original)
- **Searchable concern:** `~/src/nj/nj-2025/backend/app/models/concerns/searchable.rb`
- **SearchContent::Base:** `~/src/nj/nj-2025/backend/app/models/search_content/base.rb`
- **Example builders:** `~/src/nj/nj-2025/backend/app/models/search_content/item.rb` (complex, with projection), `person.rb`, `item_type.rb`, `tag.rb` (simple, no projection)
- **Search controller:** `~/src/nj/nj-2025/backend/app/controllers/search_controller.rb` — omnisearch across multiple models
- **Migration:** `~/src/nj/nj-2025/backend/db/migrate/20260221162042_add_search_infrastructure.rb`
- **No generator** — builders were written by hand

### Unio (added generator)
- **Generator:** `~/src/myunio/unio/backend/lib/generators/unio/searchable/searchable_generator.rb`
- **Templates:** `~/src/myunio/unio/backend/lib/generators/unio/searchable/templates/`
  - `search_content.rb.tt` — builder class with field args, weights, project mode
  - `add_search_projection_migration.rb.tt` — migration (dynamic version via `ActiveRecord::Migration.current_version`)
  - `search_tasks.rake.tt` — per-model rebuild task
  - `search_content_spec.rb.tt` — RSpec test
- **Features over NinjaNizer:** accepts field arguments with auto-weighting (A/B/C/D), `--project` flag, `--skip_model_injection`, auto-injects into model file, generates rake task per model

### Outport (latest, most refined)
- **Repo:** `~/src/outport` (github.com/myunio/outport)
- **PR:** #134 — "Add pg_search foundation with Room as first searchable model"
- **Spec document:** `~/src/outport/docs/superpowers/specs/2026-03-13-pg-search-foundation-design.md` — detailed design doc covering everything
- **Generator:** `~/src/outport/lib/generators/outport/searchable/searchable_generator.rb` — namespaced under `outport:` to avoid conflicts
- **Concern:** `~/src/outport/app/models/concerns/searchable.rb`
- **Base:** `~/src/outport/app/models/search_content/base.rb`
- **Room builder:** `~/src/outport/app/models/search_content/room.rb` — first real usage
- **Test:** `~/src/outport/test/models/search_content/room_test.rb` — Minitest
- **Changes over Unio:** namespaced generator, Minitest instead of RSpec, GIN trigram index included by default in migration template (Unio left it commented out)

## What the Gem Needs to Provide

### Core (lib/)
- `SearchablePg::Searchable` concern (or just `Searchable` — needs discussion on module naming)
- `SearchContent::Base` builder class with the full DSL: `projection`, `search_fields`, `using`, `scope_options`, `compute`, `assoc`, `custom`

### Generator
- `bin/rails generate searchable_pg:searchable ModelName field1 field2 --project`
- Templates for: builder class, migration, rake task, test (both Minitest and RSpec? or just one?)

### Railtie
- Auto-requires the concern and base class
- Makes the generator available

## Design Questions to Resolve

1. **Module naming:** When you `include Searchable` today, it's a top-level constant. In a gem, should it be `include SearchablePg::Searchable` or should the gem inject `Searchable` at the top level? Top-level is cleaner for the consumer but pollutes the namespace.

2. **SearchContent namespace:** Same question — `SearchContent::Base` is top-level today. Should it stay that way or live under `SearchablePg::SearchContent::Base`? The app-side builders (`SearchContent::Room`) would still be top-level in the consuming app.

3. **Test framework:** Generate Minitest or RSpec tests? Or detect what the app uses? Unio uses RSpec, Outport uses Minitest.

4. **Generator namespace:** In the gem it would be `searchable_pg:searchable`. The consuming app doesn't need to re-namespace.

5. **pg_search version:** Pin to a minimum version? Current apps use no pin. The gem is v2.3.7 as of today.

6. **Rails version support:** All three apps are Rails 8.1. How far back to support? The migration template uses `ActiveRecord::Migration.current_version` which works in Rails 5+.

7. **Default search strategies:** Currently hardcoded in `Base.using` (tsearch prefix+any_word+english + trigram word_similarity 0.3). Should these be configurable at the gem level, or is the current default good enough?

8. **Rebuild task pattern:** Per-model rake tasks vs a single `search:rebuild[ModelName]` task with an argument?

## Dependencies

- `pg_search` (runtime)
- `activerecord` (runtime)
- `activesupport` (runtime)
- `railties` (runtime, for generator + railtie)

## Gem Structure (typical)

```
searchable_pg/
├── lib/
│   ├── searchable_pg.rb              # Main entry, requires everything
│   ├── searchable_pg/
│   │   ├── version.rb
│   │   ├── railtie.rb
│   │   ├── searchable.rb             # The concern
│   │   └── search_content/
│   │       └── base.rb               # Builder base class
│   └── generators/
│       └── searchable_pg/
│           └── searchable/
│               ├── searchable_generator.rb
│               └── templates/
│                   ├── search_content.rb.tt
│                   ├── add_search_projection_migration.rb.tt
│                   ├── search_tasks.rake.tt
│                   └── search_content_test.rb.tt
├── spec/ or test/
├── searchable_pg.gemspec
├── Gemfile
├── Rakefile
└── README.md
```

## First Consumer

Once the gem is ready, go back to Outport (`~/src/outport`) and replace the hand-ported files with `gem "searchable_pg"`. The Searchable concern, SearchContent::Base, and generator should all come from the gem. Only the app-specific `SearchContent::Room` and customizations stay in the app.
