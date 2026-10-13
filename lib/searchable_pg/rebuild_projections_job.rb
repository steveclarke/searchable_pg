# frozen_string_literal: true

require "active_job"

module SearchablePg
  # Rebuilds every projected model's search_projection (or one model's), for
  # apps that refresh projections on a schedule.
  #
  #   SearchablePg::RebuildProjectionsJob.perform_later
  #   SearchablePg::RebuildProjectionsJob.perform_later("Person")
  class RebuildProjectionsJob < ActiveJob::Base
    queue_as :default

    def perform(model_name = nil)
      SearchablePg::Projections.rebuild(model_name)
    end
  end
end
