# frozen_string_literal: true

require "bundler/setup"
require "elasticsearch_models"
require "pry"
require "pry-byebug"
require 'rspec_junit_formatter'

require "elasticsearch_cluster_spec_helper"

RSpec.configure do |config|
  config.add_formatter RspecJunitFormatter, ENV['JUNIT_OUTPUT'] || 'spec/reports/rspec.xml'

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = "spec/reports/.rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
