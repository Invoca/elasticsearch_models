# frozen_string_literal: true

$LOAD_PATH.push(File.expand_path("lib", __dir__))

# Maintain your gem's version:
require "elasticsearch_models/version"

Gem::Specification.new do |s|
  s.name        = "elasticsearch_models"
  s.version     = ElasticsearchModels::VERSION
  s.license     = "MIT"
  s.date        = "2018-12-21"
  s.summary     = "Model representation for Elasticsearch documents"
  s.description = "Represent Elasticsearch documents as ruby models using Aggregate"
  s.authors     = ["Omeed Rabani"]
  s.email       = "orabani@invoca.com"
  s.files       = Dir["lib/**/*"]
  s.homepage    = "http://github.com/invoca/elasticsearch_models"
  s.metadata    = { "source_code_uri" => "https://github.com/Invoca/elasticsearch_models" }

  s.add_dependency "activesupport"
  s.add_dependency 'elasticsearch', '6.1.0'
  s.add_dependency "large_text_field", "~> 0.2"

  s.add_development_dependency "bundler", "~> 1.17"
  s.add_development_dependency "elasticsearch-extensions"
  s.add_development_dependency "pry"
  s.add_development_dependency "pry-byebug"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", "~> 3.0"
end
