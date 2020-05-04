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
  s.authors     = ["Invoca"]
  s.email       = "development@invoca.com"
  s.files       = Dir["lib/**/*"]
  s.homepage    = "http://github.com/invoca/elasticsearch_models"
  s.metadata    = { "allowed_push_host" => "https://gem.fury.io/invoca" }

  s.add_dependency "activesupport"
  s.add_dependency 'aggregate', '~> 2.0'
  s.add_dependency 'elasticsearch', '~> 6.8'
  s.add_dependency 'invoca-utils',  '~> 0.3'
  s.add_dependency "large_text_field", "~> 0.3"
end
