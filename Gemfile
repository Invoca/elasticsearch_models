# frozen_string_literal: true

PUBLIC_GEM_SERVER = 'https://rubygems.org'
PRIVATE_GEM_SERVER = 'https://gem.fury.io/invoca'

source PUBLIC_GEM_SERVER

gemspec

source PRIVATE_GEM_SERVER do
  gem 'aggregate'
end

gem 'appraisal'
gem 'appraisal-matrix'
gem 'elasticsearch-extensions'
gem 'pry'
gem 'pry-byebug'
gem 'rake'
gem 'rspec'
gem "rspec_junit_formatter"
gem 'rubocop', require: false
gem 'rubocop-git', require: false

gem "base64", "~> 0.2.0"
gem "bigdecimal", "~> 3.1"
gem "mutex_m", "~> 0.2.0"

gem "concurrent-ruby", "~> 1.3", "< 1.3.5"
