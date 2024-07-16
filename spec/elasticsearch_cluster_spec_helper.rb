# frozen_string_literal: true

# require 'minitest/hooks'
require 'elasticsearch/extensions/test/cluster'

module ElasticsearchClusterSpecHelper
  extend ActiveSupport::Concern
  # include Minitest::Hooks

  ELASTICSEARCH_TEST_INDEX     = "test_example_index"
  ELASTICSEARCH_TEST_LOCALHOST = ENV["ELASTICSEARCH_TEST_HOST"].presence || "127.0.0.1"
  ELASTICSEARCH_TEST_PORT      = ENV["ELASTICSEARCH_TEST_PORT"]&.to_i || 9200

  def clear_and_create_index(index: ELASTICSEARCH_TEST_INDEX)
    if @elasticsearch_test_client&.indices&.exists?(index: index)
      @elasticsearch_test_client.indices.refresh(index: index)
      @elasticsearch_test_client.delete_by_query(index: index, body: {
        query: {
          match_all: {}
        }
      })
      @elasticsearch_test_client.indices.refresh(index: index)
    else
      @elasticsearch_test_client.indices.create(index: index, timeout: "5s", body: {
        settings: {
          number_of_shards: 1,
          number_of_replicas: 0
        }
      })
    end
  end

  included do
    before(:all) do
      @elasticsearch_test_client = Elasticsearch::Client.new(host: ELASTICSEARCH_TEST_LOCALHOST, port: ELASTICSEARCH_TEST_PORT, scheme: "http")

      count = 0
      until @elasticsearch_test_client.ping
        count += 1
        raise "Elasticsearch not ready after 60 tries" if count > 60
        puts "Waiting for Elasticsearch to be ready... Attempt #{count}, sleeping 1 second"
        sleep 1
      end
    end

    before(:each) do
      clear_and_create_index
    end
  end
end
