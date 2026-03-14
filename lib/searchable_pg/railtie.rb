# frozen_string_literal: true

module SearchablePg
  class Railtie < Rails::Railtie
    # Railtie ensures the gem is loaded into the Rails boot process.
    # Top-level constants (Searchable, SearchContent::Base) are
    # registered at require time in searchable_pg.rb because class
    # inheritance evaluates before initializers run.
  end
end
