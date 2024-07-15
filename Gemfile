# frozen_string_literal: true

PUBLIC_GEM_SERVER = 'https://rubygems.org'
PRIVATE_GEM_SERVER = 'https://gem.fury.io/invoca'

source PUBLIC_GEM_SERVER

gemspec

source PRIVATE_GEM_SERVER do
  gem 'aggregate'
end

gem 'appraisal'
gem 'elasticsearch-extensions'
gem 'pry'
gem 'pry-byebug'
gem 'rake'
gem 'rspec'
gem "rspec_junit_formatter"
gem 'rubocop', require: false
gem 'rubocop-git', require: false
