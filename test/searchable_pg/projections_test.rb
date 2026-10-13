# frozen_string_literal: true

require "test_helper"
require "rake"

class ProjectionsTest < ActiveSupport::TestCase
  test "manual mode writes nothing on save" do
    person = Person.create!(name: "Ada Moss")
    person.email_addresses.create!(email: "ada@example.test")
    person.update!(name: "Ada Marsh")

    assert_nil person.reload.search_projection
  end

  test "manual rebuild reads a fresh copy, so stale loaded rows never write an old projection" do
    person = Person.create!(name: "Ada Moss")
    person.email_addresses.load
    EmailAddress.create!(person_id: person.id, email: "late@example.test")

    person.rebuild_search_projection
    assert_empty person.email_addresses.to_a, "the loaded association is left as it was"
    assert_equal "late@example.test late example.test", person.reload.search_projection
  end

  test "a manual rebuild finds a row outside the default scope" do
    sample = Person.create!(name: "Sample Person", sample: true)
    sample.phone_numbers.create!(number: "709-555-0142")
    sample.rebuild_search_projection

    assert_includes Person.unscoped.find(sample.id).search_projection, "0142"
  end

  test "lists every projected model, and rebuilds them all under each model's lock" do
    assert_equal [Contact, Person], SearchablePg::Projections.models
    person = Person.create!(name: "Ada Moss")
    person.phone_numbers.create!(number: "709-555-0142")
    contact = Contact.create!(display_name: "Jo Bell")
    Contact.where(id: contact.id).update_all(search_projection: "stale")
    Person.locked.clear

    counts = SearchablePg::Projections.rebuild
    assert_equal({Contact => 1, Person => 1}, counts)
    assert_equal [person.id], Person.locked
    assert_includes person.reload.search_projection, "5550142"
    assert_nil contact.reload.search_projection
    assert_raises(ArgumentError) { SearchablePg::Projections.rebuild("Team") }
  end

  test "the rake task and the job rebuild one model or all" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("searchable_pg:rebuild")
    Person.create!(name: "Ada Moss").phone_numbers.create!(number: "0142")

    output = capture_io { Rake::Task["searchable_pg:rebuild"].execute(Rake::TaskArguments.new([:model], ["Person"])) }.first
    assert_equal "People: 1 rebuilt\n", output
    assert_equal({Person => 1}, SearchablePg::RebuildProjectionsJob.perform_now("Person"))
  end
end
