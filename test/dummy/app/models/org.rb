# frozen_string_literal: true

# Rows of one tenant, the way acts_as_tenant scopes them.
class Org < ApplicationRecord
  include Searchable

  def self.current_tenant = Thread.current[:dummy_tenant]

  def self.with_tenant(tenant)
    previous = Thread.current[:dummy_tenant]
    Thread.current[:dummy_tenant] = tenant
    yield
  ensure
    Thread.current[:dummy_tenant] = previous
  end

  default_scope { current_tenant ? where(tenant: current_tenant) : all }

  searchable_with SearchContent::OrgName
end
