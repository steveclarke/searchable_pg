# frozen_string_literal: true

module SearchablePg
  class Railtie < Rails::Railtie
    initializer "searchable_pg.setup", before: :load_config_initializers do
      ActiveSupport.on_load(:active_record) do
        # Make Searchable available as a top-level constant
        # so models can `include Searchable` without namespacing
        ::Searchable = SearchablePg::Searchable unless defined?(::Searchable)

        # Make SearchContent::Base available as a top-level constant
        # so builders can inherit from SearchContent::Base
        unless defined?(::SearchContent)
          ::SearchContent = Module.new
          ::SearchContent::Base = SearchablePg::SearchContent::Base
        end
      end
    end
  end
end
