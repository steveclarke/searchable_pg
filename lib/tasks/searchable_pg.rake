# frozen_string_literal: true

namespace :searchable_pg do
  desc "Rebuild search_projection for one model (searchable_pg:rebuild[Person]) or every projected model"
  task :rebuild, [:model] => :environment do |_task, args|
    SearchablePg::Projections.rebuild(args[:model]) do |model, count|
      puts "#{model.model_name.plural.humanize}: #{count} rebuilt"
    end
  end
end
