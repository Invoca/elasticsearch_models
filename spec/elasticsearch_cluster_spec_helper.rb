# frozen_string_literal: true

# require 'minitest/hooks'
require 'elasticsearch/extensions/test/cluster'

module ElasticsearchClusterSpecHelper
  extend ActiveSupport::Concern
  # include Minitest::Hooks

  ELASTICSEARCH_TEST_INDEX     = "test_example_index"
  ELASTICSEARCH_TEST_LOCALHOST = ENV["ELASTICSEARCH_TEST_HOST"].presence || "127.0.0.1"
  ELASTICSEARCH_TEST_PORT      = ENV["ELASTICSEARCH_TEST_PORT"]&.to_i || 9250

  # If using Minitest, use Minitest::Hooks.

  # `export ELASTICSEARCH_TEST_PORT=9200` to run tests against your local, running Elasticsearch

  # If you run into issues with Webmock, make sure to allow local requests
  # WebMock.disable_net_connect!(allow_localhost: true) # allow local requests in setup
  # WebMock.disable_net_connect! # disallow all requests in teardown

  CLUSTER_COMMANDS =
    if ENV["SEMAPHORE_CI_ELASTICSEARCH"].present?
      { command: "/usr/share/elasticsearch/bin/elasticsearch", es_params: "-E path.conf=/etc/elasticsearch/" }
    else
      {}
    end.freeze

  def clear_and_create_index(index: ELASTICSEARCH_TEST_INDEX)
    if @elasticsearch_test_client&.indices&.exists?(index: index)
      @elasticsearch_test_client.indices.delete(index: index)
    end

    unless @elasticsearch_test_client&.indices&.exists?(index: index)
      @elasticsearch_test_client.indices.create(index: index)
    end
  end

  included do
    before(:all) do
      if ELASTICSEARCH_TEST_PORT == 9250 && ELASTICSEARCH_TEST_LOCALHOST == '127.0.0.1'
        Elasticsearch::Extensions::Test::Cluster.start(CLUSTER_COMMANDS.merge(port: ELASTICSEARCH_TEST_PORT, number_of_nodes: 1, timeout: 20))
      end

      @elasticsearch_test_client = Elasticsearch::Client.new(host: ELASTICSEARCH_TEST_LOCALHOST, port: ELASTICSEARCH_TEST_PORT, scheme: "http")
    end

    after(:all) do
      if ELASTICSEARCH_TEST_PORT == 9250 && ELASTICSEARCH_TEST_LOCALHOST == '127.0.0.1'
        Elasticsearch::Extensions::Test::Cluster.stop(CLUSTER_COMMANDS.merge(port: ELASTICSEARCH_TEST_PORT))
      end
    end

    before(:each) do
      clear_and_create_index
    end
  end
end
