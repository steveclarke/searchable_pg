# frozen_string_literal: true

ActiveRecord::Schema.define do
  enable_extension "pg_trgm"
  enable_extension "unaccent"

  create_table :users, force: true do |t|
    t.boolean :office, null: false, default: false
    t.bigint :team_ids, array: true, null: false, default: []
  end

  create_table :people, force: true do |t|
    t.string :name
    t.string :legal_name
    t.text :search_projection
    t.boolean :sample, null: false, default: false
    t.timestamps
  end

  create_table :contacts, force: true do |t|
    t.string :display_name
    t.text :search_projection
    t.timestamps
  end

  create_table :email_addresses, force: true do |t|
    t.references :person
    t.references :contact
    t.string :email
    t.timestamps
  end

  create_table :phone_numbers, force: true do |t|
    t.references :person
    t.references :contact
    t.string :number
    t.timestamps
  end

  create_table :teams, force: true do |t|
    t.string :name
  end

  create_table :events, force: true do |t|
    t.string :title
    t.text :body
    t.boolean :draft, null: false, default: false
    t.boolean :past, null: false, default: false
  end

  create_table :orgs, force: true do |t|
    t.string :name
    t.string :tenant
  end
end
