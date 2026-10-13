# frozen_string_literal: true

# Records any_word_golden.json by running a given version of the gem's lib on
# the corpus, outside the dummy app:
#
#   git worktree add /tmp/searchable_pg-0.1 13396b9
#   DATABASE_URL=postgres://... bundle exec ruby test/fixtures/record_any_word_golden.rb /tmp/searchable_pg-0.1/lib
lib = ARGV.fetch(0)
$LOAD_PATH.unshift(lib)
require "json"
require "yaml"
require "searchable_pg"

ActiveRecord::Base.establish_connection(ENV.fetch("DATABASE_URL", "postgres://postgres:nitro@127.0.0.1:54329/searchable_pg_golden"))
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  enable_extension "pg_trgm"
  enable_extension "unaccent"
  create_table(:golden_contacts, force: true) { |t|
    t.string :display_name
    t.text :search_projection
    t.timestamps
  }
  create_table(:golden_emails, force: true) { |t|
    t.references :golden_contact
    t.string :email
    t.timestamps
  }
  create_table(:golden_phones, force: true) { |t|
    t.references :golden_contact
    t.string :number
    t.timestamps
  }
end

module SearchContent
  class GoldenContact < SearchContent::Base
    def self.search_fields = {display_name: "A", search_projection: nil}
    def self.scope_options = {ignoring: :accents}

    projection do
      assoc(:golden_emails) { |e| e.email }
      assoc(:golden_phones) { |p| p.number }
    end
  end
end

class GoldenEmail < ActiveRecord::Base
  belongs_to :golden_contact, touch: true
end

class GoldenPhone < ActiveRecord::Base
  belongs_to :golden_contact, touch: true
end

class GoldenContact < ActiveRecord::Base
  include Searchable

  has_many :golden_emails
  has_many :golden_phones
  searchable_with SearchContent::GoldenContact, project: true
end

here = __dir__
YAML.load_file(File.join(here, "any_word_corpus.yml")).fetch("contacts").each do |row|
  contact = GoldenContact.create!(display_name: row.fetch("name"))
  Array(row["emails"]).each { |email| contact.golden_emails.create!(email:) }
  Array(row["phones"]).each { |number| contact.golden_phones.create!(number:) }
end
queries = File.readlines(File.join(here, "any_word_queries.txt"), chomp: true).reject(&:empty?)
golden = queries.to_h { |query| [query, GoldenContact.search(query).map(&:display_name)] }
File.write(File.join(here, "any_word_golden.json"), "#{JSON.pretty_generate(golden)}\n")
puts "#{golden.size} queries recorded with #{lib}"
