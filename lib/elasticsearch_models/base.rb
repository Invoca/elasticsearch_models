# frozen_string_literal: true

module ElasticsearchModels
  class Base < ElasticsearchModels::Aggregate
    include ElasticsearchModels::DeepSquash

    class CreateError < StandardError; end

    # Metadata fields that can not be set when created
    METADATA_FIELDS = [:_id, :_index, :_type].freeze

    attribute :_id,    :string
    attribute :_index, :string
    attribute :_type,  :string

    class << self
      def create!(*params)
        model = new(*params)
        model.validate!
        response = client_connection.index(index: model.index_name, type: model.type, body: model.deep_squash_to_store)

        if response.dig("_shards", "successful").to_i > 0
          model.assign_metadata_fields(response)
          model
        else
          raise CreateError, "Error creating elasticsearch model. Params: #{params.inspect}. Response: #{response.inspect}"
        end
      end

      def where(**params)
        search_params = Query::Builder.new(index_name, type, params).search_params
        Query::Response.new(client_connection.search(search_params))
      end

      def client_connection
        raise NotImplementedError # Should return Elasticsearch::Client
      end

      def index_name
        raise NotImplementedError
      end

      def type
        name
      end

      def from_store(search_hit)
        model = super(search_hit["_source"])
        model.assign_metadata_fields(search_hit)
        model
      end
    end

    def index_name
      self.class.index_name
    end

    def type
      self.class.type
    end

    def deep_squash_to_store
      deep_squash(to_store)
    end

    def assign_metadata_fields(response_hash)
      response = response_hash.symbolize_keys
      METADATA_FIELDS.each do |field|
        send("#{field}=", response.dig(field))
      end
    end
  end
end
