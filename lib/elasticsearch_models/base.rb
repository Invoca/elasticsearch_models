# frozen_string_literal: true

module ElasticsearchModels
  class Base < ElasticsearchModels::Aggregate
    include ElasticsearchModels::DeepSquash

    class CreateError < StandardError; end

    # ElasticSearch is deprecating _type field, however it is still required.
    DEPRECATED_TYPE = "ElasticsearchModel"

    # Metadata fields that can not be set when created
    METADATA_FIELDS = [:_id, :_index, :_type].freeze

    attribute :_id,    :string
    attribute :_index, :string
    attribute :_type,  :string

    # Used for rehydrating and querying: these should not be changed
    attribute          :rehydration_class, :string
    aggregate_has_many :query_types, :string

    class << self
      def create!(*params)
        model = new(*params)
        model.rehydration_class = type
        model.query_types       = query_types
        model.validate!
        response = client_connection.index(index: model.index_name, type: DEPRECATED_TYPE, body: model.deep_squash_to_store)

        if response.dig("_shards", "successful").to_i > 0
          model.assign_metadata_fields(response)
          model
        else
          raise CreateError, "Error creating elasticsearch model. Params: #{params.inspect}. Response: #{response.inspect}"
        end
      end

      def where(**params)
        Query::Response.new(client_connection.search(query_params(**params)))
      end

      def count(**params)
        client_connection.count(query_params(**params))["count"]
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

      def query_types
        class_names = ancestors.select { |ancestor| ancestor.is_a?(Class) }
        class_names.take_while { |klass| klass != ElasticsearchModels::Base }.map(&:name) # returns all parent classes up to ElasticsearchModels::Base
      end

      private

      def query_params(**params)
        params_with_indices = params[:_indices] ? params : params.merge(_indices: index_name)
        Query::Builder.new(params_with_indices.merge(query_types: type)).search_params
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
