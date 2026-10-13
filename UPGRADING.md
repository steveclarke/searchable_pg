# Upgrading

## 0.1 to 0.2

Nothing changes for an app that only bumps the version: matching stays `:any_word` and projections stay on callbacks.

1. Pin the release: `gem "searchable_pg", github: "steveclarke/searchable_pg", tag: "v0.2.0"`, then `bundle update searchable_pg`.
2. Run `bin/rails generate searchable_pg:install` to write today's defaults into `config/initializers/searchable_pg.rb`.
3. Replace per-model rebuild tasks (`lib/tasks/search/rebuild_*.rake`, any `search:rebuild_all`) with `bin/rails searchable_pg:rebuild`, which covers every projected model.
4. Where a test asserts an empty projection is `""`, expect `nil`.
5. Optional, one builder at a time: `matching :every_word` for name and title searches, with `near_spelling` and `order_within_rank`. Compare each list's results before and after.

### Moving from an in-app copy

1. Remove the app's `app/models/concerns/searchable.rb` and `app/models/search_content/base.rb` in the same commit as adding the gem; otherwise whichever loads first wins.
2. Set the matching and projection settings the copy used (`c.matching = :every_word`, `c.projection_rebuild = :manual`, and so on).
3. Check `Person.method(:searchable_with).source_location` points into the gem.
