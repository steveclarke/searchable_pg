# frozen_string_literal: true

# Required before the gem, this keeps `::Searchable` and `::SearchContent`
# undefined; models then write `SearchablePg::Searchable` and
# `SearchablePg::SearchContent::Base`.
#
#   gem "searchable_pg", require: ["searchable_pg/no_aliases", "searchable_pg"]
module SearchablePg
  NO_ALIASES = true
end
