# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :rubocop do
  puts
  puts "rubocop"
  rubocop_output = `rubocop`
  print rubocop_output
  unless rubocop_output =~ /files inspected, no offenses detected/
    exit 1
  end
end

task default: [:spec, :rubocop]
