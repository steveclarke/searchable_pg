# Changelog

All notable changes are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [SemVer](https://semver.org/).

## [Unreleased]

## [0.2.0] - 2026-10-13

Everything is additive: an app that changes nothing keeps 0.1.0's results.

### Added

- Per-builder matching rules: `matching :any_word | :every_word`, `dictionary`, `trigram_threshold`, `near_spelling`, `order_within_rank`, `ranked_by`, `ignoring`, inherited by subclasses.
- `:every_word` matching: the whole query ranks and each word must also match, on the relation the search was called on (tenant and default scopes hold in the subquery); `SearchablePg.normalize` prepares the query; the whole-query scope stays public as `"#{scope}_ranked"`.
- App-wide settings (`SearchablePg.configure`: `matching`, `trigram_threshold`, `projection_rebuild`), frozen after boot, and `rails g searchable_pg:install` to write them.
- `scope:` on `searchable_with`, for several scopes per model.
- Manual projections (`rebuild: :manual`): no callbacks; `rebuild_search_projection` reads a fresh copy and writes with `update_column`. `rebuild_lock:` wraps each write of a full rebuild.
- Projection helpers `compute_many`, `project_emails`, `email_tokens`, `project_phones`, `phone_tokens`, `project_addresses`.
- `SearchablePg::Projections`: every projected model registered; `rake searchable_pg:rebuild[Model]` and `SearchablePg::RebuildProjectionsJob`.
- Opt-in global search (`SearchablePg::Global`, autoloaded): registry of kinds, ActionPolicy and Pundit adapters, `Query` (visible check, policy scope before limit, `more`, see-all paging, top hit, per-kind statement timeout, `partial`), `Snippet`, `Endpoint` concern, `rails g searchable_pg:global`.
- `rails g searchable_pg:global_frontend`: `searchGroups.ts`, `useRemoteSearch.ts`, `useRecentItems.ts`.
- Testing helpers for RSpec and Minitest, including a check that no kind matches on a private column.
- `require "searchable_pg/no_aliases"` to leave out the top-level constants.
- Test suite on real PostgreSQL with a dummy app; CI across Ruby 3.3 to 4.0, Rails 8.0 and 8.1, PostgreSQL 16 and 18.

### Changed

- An empty projection is stored as `nil` (was `""`). Search results are the same.
- The searchable generator no longer writes a per-model rake task; `searchable_pg:rebuild` covers every model.
- Requires Ruby 3.3+, Rails 8.0+ and pg_search 2.3.7+.

## [0.1.0] - 2026-05-31

- `Searchable` concern, `SearchContent::Base` builder with the projection DSL (`assoc`, `compute`, `custom`), and the `searchable_pg:searchable` generator.

[Unreleased]: https://github.com/steveclarke/searchable_pg/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/steveclarke/searchable_pg/compare/13396b9...v0.2.0
[0.1.0]: https://github.com/steveclarke/searchable_pg/commit/13396b9
