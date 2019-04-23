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

    def save!
      new_record? or raise "Model already saved, cannot be saved again"
      validate!

      if (result = self.class.insert!(deep_squash_to_store, index_name))
        assign_metadata_fields(result)
        self
      end
    end

    def new_record?
      _id.nil?
    end

    def initialize(*params)
      super
      if params.last.is_a?(Hash) # Constructed new, not rehydrated
        self.rehydration_class = self.class.type
        self.query_types       = self.class.query_types
      end
    end

    class << self
      def create!(*params)
        new(*params).save!
      end

      def insert!(body_hash, index)
        body_hash.is_a?(Hash) or raise ArgumentError, "body_hash must be of type Hash, was of type #{body_hash.class}."
        response = client_connection.index(index: index, type: DEPRECATED_TYPE, body: body_hash)
        if response.dig("_shards", "successful").to_i > 0
          response
        else
          raise CreateError, "Error creating elasticsearch model. Body: #{body_hash.inspect}. Response: #{response.inspect}"
        end
      end

      def where(**params)
        Query::Response.new(client_connection.search(query_params(**params)), self)
      end

      def count(**params)
        client_connection.count(query_params(**params))["count"]
      end

      def distinct_values(field, additional_fields: [], where: {}, **params)
        field.presence.is_a?(String) or raise ArgumentError, "field must be a present String"
        additional_fields.all? { |f| f.presence.is_a?(String) } or raise ArgumentError, "additional_fields must all be present Strings"

        response = where(_aggs: { field: field, aggs: additional_fields.presence, **params }.compact, **where.merge(_size: 0))
        distinct_values_response(response.aggregations, additional_fields: additional_fields)
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

      # Derived classes can use this to provide alternate search terms in the case of model changes
      def search_type
        type
      end

      # Derived classes can replace this method in order to handle changes to class names or to restrict
      # the classes that are returned
      def model_class_from_name(class_name)
        class_name.constantize
      end

      def from_store(search_hit)
        model = super(search_hit["_source"])
        model.assign_metadata_fields(search_hit)
        model
      end

      def query_types
        parent_classes = ancestors.select { |ancestor| ancestor.is_a?(Class) }

        # return all parent classes up to ElasticsearchModels::Base
        parent_classes.take_while { |klass| klass != ElasticsearchModels::Base }.map(&:name)
      end

      private

      def query_params(**params)
        params_with_indices = params[:_indices] ? params : params.merge(_indices: index_name)
        Query::Builder.new(params_with_indices.merge(query_types: search_type)).search_params
      end

      def distinct_values_response(aggregations, additional_fields: [])
        aggregations.each_with_object({}) do |(field, values), result|
          result[field] =
            if additional_fields.present?
              values["buckets"].build_hash do |item|
                [item["key"], distinct_values_response(item & additional_fields)]
              end
            else
              values["buckets"].map { |item| item["key"] }
            end
        end
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
