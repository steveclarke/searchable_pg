source "https://rubygems.org"

# Specify your gem's dependencies in searchable_pg.gemspec
gemspec

# CI tests each supported Rails: RAILS_VERSION=8.0 bundle install
rails_version = ENV.fetch("RAILS_VERSION", "8.1")
if rails_version == "main"
  gem "rails", github: "rails/rails", branch: "main"
else
  gem "rails", "~> #{rails_version}.0"
end

gem "irb"
gem "rake", "~> 13.0"
gem "pg", "~> 1.5"
gem "minitest", "~> 5.25"
gem "action_policy", "~> 0.7"
gem "pundit", "~> 2.5"
gem "standard", "~> 1.50", require: false
gem "rspec-expectations", "~> 3.13"
