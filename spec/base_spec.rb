# frozen_string_literal: true

RSpec.describe ElasticsearchModels::Base do
  include ElasticsearchClusterSpecHelper

  def refresh_index(index_name: DummyElasticSearchModel.index_name)
    # To ensure we get back the document we just indexed in
    @elasticsearch_test_client.indices.refresh(index: index_name)
  end

  def refresh_and_find_search_hit
    refresh_index
    search_response = @elasticsearch_test_client.search(index: DummyElasticSearchModel.index_name)
    expect(search_response.dig("hits", "total")).to eq(1)

    search_response.dig("hits", "hits").first
  end

  def expect_response_models_match(response_models, expected_models)
    expect(response_models.sort_by(&:_id).map(&:to_store)).to eq(expected_models.sort_by(&:_id).map(&:to_store))
  end

  class DummyOwnerClass
    attr_accessor :id

    class << self
      attr_accessor :find_value

      def find(_value)
        find_value
      end
    end
  end

  class DummyElasticSearchModel < ElasticsearchModels::Base
    class NestedAggregateAttribute < ElasticsearchModels::Aggregate
      class NestedBoolAttribute < ElasticsearchModels::Aggregate
        attribute :nested_bool,  :boolean
        attribute :ignored_bool, :boolean
      end

      attribute :nested_string_field, :string
      attribute :nested_int_field,    :integer
      attribute :nested_hash_field,   :hash
      attribute :nested_bool_class,   NestedBoolAttribute
    end

    attribute :my_string,       :string,  required: true
    attribute :my_other_string, :string
    attribute :my_bool,         :boolean, default: false
    attribute :my_hash,         :hash
    attribute :my_int,          :integer
    attribute :my_time,         :datetime
    attribute :my_float,        :float
    attribute :my_enum,         :enum,    limit: [:Yes, :No, :Maybe]
    attribute :my_decimal,      :decimal
    attribute :my_nested_class, NestedAggregateAttribute

    aggregate_has_many :nested_aggregate_classes, NestedAggregateAttribute

    belongs_to :dummy_owner, class_name: DummyOwnerClass

    CURRENT_SCHEMA_VERSION = "1.0"
    aggregate_schema_version CURRENT_SCHEMA_VERSION, :fixup_aggregate_schema

    class << self
      def index_name
        ElasticsearchClusterSpecHelper::ELASTICSEARCH_TEST_INDEX
      end

      def client_connection
        @client_connection ||= Elasticsearch::Client.new(host: "127.0.0.1", port: ENV["ELASTICSEARCH_TEST_PORT"] || 9250, scheme: "http")
      end

      def model_class_from_name(class_name)
        if class_name == "DummyReplacedModel"
          DummySub1BModel
        else
          super
        end
      end
    end

    def fixup_aggregate_schema(loaded_version)
      if loaded_version == "0.5"
        self.my_other_string = my_string
      end
    end
  end

  class DummySub1AModel < DummyElasticSearchModel
    attribute :my_dummy_sub_attr, :integer
  end

  class DummySub2AModel < DummySub1AModel; end
  class DummySub1BModel < DummyElasticSearchModel
    def self.search_type
      ["DummyReplacedModel", *super]
    end
  end

  class DummyUniqueIndexModel < DummyElasticSearchModel
    def self.index_name
      "unique_index"
    end
  end

  class DummyReplacedModel < DummyElasticSearchModel; end

  context "DummyElasticSearchModel" do
    it "inherits from ElasticsearchModels::Base and Aggregate::Base" do
      dummy_model = DummyElasticSearchModel.create!(my_string: "Hello")
      expect(dummy_model.is_a?(ElasticsearchModels::Base)).to eq(true)
      expect(dummy_model.is_a?(Aggregate::Base)).to eq(true)
    end

    context "#index_name" do
      it "returns implemented response" do
        expect(DummyElasticSearchModel.create!(my_string: "Hello").index_name).to eq(DummyElasticSearchModel.index_name)
      end

      it "raises NotImplementedError if not defined" do
        expect { ElasticsearchModels::Base.new.index_name }.to raise_error(NotImplementedError)
      end
    end

    context "#type" do
      it "returns class name" do
        expect(DummyElasticSearchModel.create!(my_string: "Hello").type).to eq("DummyElasticSearchModel")
      end
    end

    context "#deep_squash_to_store" do
      it "deep squashes all fields in to_store by removing empty hashes and empty arrays" do
        dummy_model = DummyElasticSearchModel.create!(my_string: "Hello", my_hash: { "a" => [] })

        expected_metadata_fields = { "_id" => dummy_model._id, "_type" => "ElasticsearchModel", "_index" => "test_example_index" }
        expected_to_store = {
          "my_string"                => "Hello",
          "my_other_string"          => nil,
          "my_bool"                  => false,
          "my_hash"                  => "{\"a\":[]}",
          "my_int"                   => nil,
          "my_time"                  => nil,
          "my_float"                 => nil,
          "my_enum"                  => nil,
          "my_decimal"               => nil,
          "my_nested_class"          => nil,
          "nested_aggregate_classes" => [],
          "dummy_owner_id"           => nil,
          "data_schema_version"      => "1.0",
          "rehydration_class"        => "DummyElasticSearchModel",
          "query_types"              => ["DummyElasticSearchModel"]
        }.merge(expected_metadata_fields)
        expect(dummy_model.to_store).to eq(expected_to_store)

        expected_deep_squash_to_store = {
          "my_string"           => "Hello",
          "my_bool"             => false,
          "my_hash"             => "{\"a\":[]}",
          "data_schema_version" => "1.0",
          "rehydration_class"   => "DummyElasticSearchModel",
          "query_types"         => ["DummyElasticSearchModel"]
        }.merge(expected_metadata_fields)
        expect(dummy_model.deep_squash_to_store).to eq(expected_deep_squash_to_store)
      end
    end

    context "#assign_metadata_fields" do
      it "defines METADATA_FIELDS" do
        expect(ElasticsearchModels::Base::METADATA_FIELDS).to eq([:_id, :_index, :_type])
      end

      it "sets metadata with indifferent key access" do
        metadata_fields = {
          "_id" => "i5JhrmcBUU6q7YBzawfu",
          :_index => "test_index",
          "_type" => "ElasticsearchModel"
        }
        model = DummyElasticSearchModel.new(my_string: "Hello")
        model.assign_metadata_fields(metadata_fields)
        ElasticsearchModels::Base::METADATA_FIELDS.each do |metadata_field|
          expect(metadata_fields.with_indifferent_access[metadata_field]).to eq(model.send(metadata_field))
        end
      end
    end

    context ".from_store" do
      it "returns rehydrated model with metadata_fields assigned" do
        decoded_aggregate_store = {
          "_index" => "test_index",
          "_type"  => "ElasticsearchModel",
          "_id"    => "i5JhrmcBUU6q7YBzawfu",
          "_score" => 4.2685113,
          "_source" => {
            "my_string"          => "Hello",
            "my_bool"            => false,
            "my_int"             => 150,
            "rehydration_class"  => "DummyElasticSearchModel",
            "query_types"        => ["DummyElasticSearchModel"]
          }
        }

        model = DummyElasticSearchModel.from_store(decoded_aggregate_store)
        expected_aggregate_attributes = {
          "_id"                      => "i5JhrmcBUU6q7YBzawfu",
          "_index"                   => "test_index",
          "_type"                    => "ElasticsearchModel",
          "my_string"                => "Hello",
          "my_other_string"          => nil,
          "my_bool"                  => false,
          "my_hash"                  => {},
          "my_int"                   => 150,
          "my_time"                  => nil,
          "my_float"                 => nil,
          "my_enum"                  => nil,
          "my_decimal"               => nil,
          "my_nested_class"          => nil,
          "nested_aggregate_classes" => [],
          "dummy_owner_id"           => nil,
          "data_schema_version"      => nil,
          "rehydration_class"        => "DummyElasticSearchModel",
          "query_types"              => ["DummyElasticSearchModel"]
        }
        expect(model.aggregate_attributes).to eq(expected_aggregate_attributes)
      end
    end

    context ".create!" do
      before(:each) do
        @default_fields = { "my_string" => "Hello", "my_bool" => false,
                            "data_schema_version" => "1.0",
                            "my_hash"             => "{}",
                            "rehydration_class"   => "DummyElasticSearchModel",
                            "query_types"         => ["DummyElasticSearchModel"] }
      end

      it "submits with index and type" do
        dummy_model = DummyElasticSearchModel.create!(my_string: "Hello")

        search_hit = refresh_and_find_search_hit
        expect(search_hit["_index"]).to eq(dummy_model.index_name)
        expect(search_hit["_source"]["rehydration_class"]).to eq(dummy_model.type)
      end

      it "returns model with filled attributes and elasticsearch metadata fields" do
        dummy_model = DummyElasticSearchModel.create!(my_string: "Hello")

        search_hit = refresh_and_find_search_hit
        ElasticsearchModels::Base::METADATA_FIELDS.each do |metadata_field|
          expect(search_hit.with_indifferent_access[metadata_field]).to eq(dummy_model.send(metadata_field))
        end

        expect(refresh_and_find_search_hit["_source"]).to eq(@default_fields)
        expect(dummy_model.my_string).to eq("Hello")
        expect(dummy_model.my_bool).to eq(false)
      end

      it "raises an exception if the elasticsearch insert is not successful on any shard" do
        dummy_connection = Elasticsearch::Client.new
        expect(DummyElasticSearchModel).to receive(:client_connection).and_return(dummy_connection)

        error_response = {
          "_shards" => {
            "total"      => 2,
            "successful" => 0,
            "failed"     => 1
          }
        }
        expect(dummy_connection).to receive(:index).and_return(error_response)

        expected_error = "Error creating elasticsearch model. Body: {\"rehydration_class\"=>\"DummyElasticSearchModel\", "\
                         "\"query_types\"=>[\"DummyElasticSearchModel\"], \"my_string\"=>\"Hello\", \"my_bool\"=>false, \"my_hash\"=>\"{}\", "\
                         "\"data_schema_version\"=>\"1.0\"}. Response: {\"_shards\"=>{\"total\"=>2, \"successful\"=>0, \"failed\"=>1}}"
        expect { DummyElasticSearchModel.create!(my_string: "Hello") }.to raise_error(ElasticsearchModels::Base::CreateError, expected_error)
      end

      # _id is tested separately and gives an cannot save twice error.  (Tested with save!)
      (ElasticsearchModels::Base::METADATA_FIELDS - [:_id]).each do |metadata_field|
        it "raises error when attempting to set metadata field '#{metadata_field}' on model" do
          expected_error = /Field \[#{metadata_field}\] is a metadata field and cannot be added inside a document/
          expect do
            DummyElasticSearchModel.create!({ my_string: "Hello" }.merge(metadata_field => "12345"))
          end.to raise_error(Elasticsearch::Transport::Transport::Errors::BadRequest, expected_error)
        end
      end

      it "ignores all nil or empty attributes and include data_schema_version" do
        DummyElasticSearchModel.create!(my_string: "Hello")
        expect(refresh_and_find_search_hit["_source"]).to eq(@default_fields)
      end

      it "validates the model before attempting to insert to Elasticsearch" do
        expect { DummyElasticSearchModel.create! }.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: My string must be set")

        refresh_index
        search_response = @elasticsearch_test_client.search(index: DummyElasticSearchModel.index_name)
        expect(search_response.dig("hits", "total")).to eq(0)
      end

      context "attributes" do
        it "stores string" do
          DummyElasticSearchModel.create!(my_string: "Hello")
          expect(refresh_and_find_search_hit["_source"]).to eq(@default_fields)
        end

        it "stores boolean" do
          DummyElasticSearchModel.create!(my_string: "Hello", my_bool: false)
          expect(refresh_and_find_search_hit["_source"]).to eq(@default_fields.merge("my_bool" => false))
        end

        it "stores hash" do
          DummyElasticSearchModel.create!(my_string: "Hello", my_hash: { a: { b: 1 } })
          expect(refresh_and_find_search_hit["_source"]).to eq(@default_fields.merge("my_hash" => "{\"a\":{\"b\":1}}"))
        end

        it "stores int" do
          DummyElasticSearchModel.create!(my_string: "Hello", my_int: 9_000)
          expect(refresh_and_find_search_hit["_source"]).to eq(@default_fields.merge("my_int" => 9_000))
        end

        it "stores datetime in UTC" do
          time = Time.at(1_544_657_724)
          DummyElasticSearchModel.create!(my_string: "Hello", my_time: time)
          expect(refresh_and_find_search_hit["_source"]).to eq(@default_fields.merge("my_time" => "2018-12-12T23:35:24Z"))
        end

        it "stores float" do
          DummyElasticSearchModel.create!(my_string: "Hello", my_float: Float(1.123456789))
          expect(refresh_and_find_search_hit["_source"]).to eq(@default_fields.merge("my_float" => 1.123456789))
        end

        it "stores enum" do
          DummyElasticSearchModel.create!(my_string: "Hello", my_enum: :Maybe)
          expect(refresh_and_find_search_hit["_source"]).to eq(@default_fields.merge("my_enum" => "Maybe"))
        end

        it "stores decimal" do
          DummyElasticSearchModel.create!(my_string: "Hello", my_decimal: BigDecimal(123_456_789))
          expect(refresh_and_find_search_hit["_source"]).to eq(@default_fields.merge("my_decimal" => "123456789.0"))
        end

        context "nested aggregate" do
          it "stores nested aggregate as a hash" do
            nested_bool = DummyElasticSearchModel::NestedAggregateAttribute::NestedBoolAttribute.new(nested_bool: true)
            nested_attr = DummyElasticSearchModel::NestedAggregateAttribute.new(nested_int_field:    100,
                                                                                nested_string_field: "Hi",
                                                                                nested_hash_field:   { a: 1 },
                                                                                nested_bool_class:   nested_bool)

            DummyElasticSearchModel.create!(my_string: "Hello", my_nested_class: nested_attr)

            expected_additional_fields = {
              "my_nested_class" => {
                "nested_string_field" => "Hi",
                "nested_int_field"    => 100,
                "nested_hash_field"   => "{\"a\":1}",
                "nested_bool_class" => {
                  "nested_bool" => true
                }
              }
            }
            expect(refresh_and_find_search_hit["_source"]).to eq(@default_fields.merge(expected_additional_fields))
          end

          it "compacts blank nested aggregate fields" do
            nested_attr = DummyElasticSearchModel::NestedAggregateAttribute.new(nested_int_field: 100)
            DummyElasticSearchModel.create!(my_string: "Hello", my_nested_class: nested_attr)

            expected_additional_fields = {
              "my_nested_class" => {
                "nested_hash_field" => "{}",
                "nested_int_field"  => 100
              }
            }
            expect(refresh_and_find_search_hit["_source"]).to eq(@default_fields.merge(expected_additional_fields))
          end
        end

        context "has_many" do
          it "stores has_many as an array" do
            nested_bool = DummyElasticSearchModel::NestedAggregateAttribute::NestedBoolAttribute.new(nested_bool: true)
            nested_attr = DummyElasticSearchModel::NestedAggregateAttribute.new(nested_int_field:    100,
                                                                                nested_string_field: "Hi",
                                                                                nested_hash_field:   { a: 1 },
                                                                                nested_bool_class:   nested_bool)

            DummyElasticSearchModel.create!(my_string: "Hello", nested_aggregate_classes: [nested_attr] * 2)

            expected_additional_fields = {
              "rehydration_class"        => "DummyElasticSearchModel",
              "nested_aggregate_classes" => [
                {
                  "nested_string_field" => "Hi",
                  "nested_int_field"    => 100,
                  "nested_hash_field"   => "{\"a\":1}",
                  "nested_bool_class" => {
                    "nested_bool" => true
                  }
                }
              ] * 2
            }
            expect(refresh_and_find_search_hit["_source"]).to eq(@default_fields.merge(expected_additional_fields))
          end

          it "compacts blank nested item fields" do
            nested_attr = DummyElasticSearchModel::NestedAggregateAttribute.new(nested_int_field: 100)
            DummyElasticSearchModel.create!(my_string: "Hello", nested_aggregate_classes: [nested_attr] * 2)

            expected_additional_fields = { "nested_aggregate_classes" => [{ "nested_hash_field" => "{}", "nested_int_field" => 100 }] * 2 }
            expect(refresh_and_find_search_hit["_source"]).to eq(@default_fields.merge(expected_additional_fields))
          end
        end

        context "belongs_to" do
          it "stores belongs_to owner id" do
            dummy_owner    = DummyOwnerClass.new
            dummy_owner.id = 1
            DummyOwnerClass.find_value = dummy_owner

            DummyElasticSearchModel.create!(my_string: "Hello", dummy_owner_id: dummy_owner.id)

            expect(refresh_and_find_search_hit["_source"]).to eq(@default_fields.merge("dummy_owner_id" => 1))
          end
        end
      end

      context "new and save" do
        it "supports calling new and then saving later" do
          dummy_model = DummyElasticSearchModel.new(my_string: "Hello")

          # Not saved yet
          refresh_index
          search_response = @elasticsearch_test_client.search(index: DummyElasticSearchModel.index_name)
          expect(search_response.dig("hits", "total")).to eq(0)

          dummy_model.save!
          search_hit = refresh_and_find_search_hit
          expect(search_hit["_index"]).to eq(dummy_model.index_name)
          expect(search_hit["_source"]["rehydration_class"]).to eq(dummy_model.type)
        end

        it "does not allow save to be called on a model that has already been updated" do
          dummy_model = DummyElasticSearchModel.create!(my_string: "Hello")

          expect { dummy_model.save! }.to raise_error(RuntimeError, "Model already saved, cannot be saved again")
        end

        it "does not allow save to be called on a model that has already been loaded" do
          DummyElasticSearchModel.create!(my_string: "Hello")
          refresh_index
          dummy_model = DummyElasticSearchModel.where.models.first
          expect { dummy_model.save! }.to raise_error(RuntimeError, "Model already saved, cannot be saved again")
        end

        it "can handle an empty result from insert!" do
          dummy_model = DummyElasticSearchModel.new(my_string: "Hello")
          expect(DummyElasticSearchModel).to receive(:insert!).with(any_args).and_return(nil)
          expect(dummy_model.save!).to eq(nil)
        end
      end

      context "new_record?" do
        it "is true for a new record" do
          dummy_model = DummyElasticSearchModel.new(my_string: "Hello")
          expect(dummy_model.new_record?).to eq(true)
        end

        it "is false for a record after it has been saved" do
          dummy_model = DummyElasticSearchModel.create!(my_string: "Hello")
          expect(dummy_model.new_record?).to eq(false)
        end

        it "is false for a record after it has been loaded from Elastisearch" do
          DummyElasticSearchModel.create!(my_string: "Hello")
          refresh_index
          dummy_model = DummyElasticSearchModel.where.models.first
          expect(dummy_model.new_record?).to eq(false)
        end
      end

      it "inserts to Elasticsearch based on index_name and type with non-nil attributes as the source" do
        current_time            = Time.now
        nested_bool             = DummyElasticSearchModel::NestedAggregateAttribute::NestedBoolAttribute.new(nested_bool: true)
        nested_attr_with_string = DummyElasticSearchModel::NestedAggregateAttribute.new(nested_string_field: "nested", nested_bool_class: nested_bool)
        nested_attr_with_int    = DummyElasticSearchModel::NestedAggregateAttribute.new(nested_int_field:  100,
                                                                                        nested_hash_field: { a: 1 },
                                                                                        nested_bool_class: nested_bool)

        DummyElasticSearchModel.create!(my_string:                "Hello",
                                        my_bool:                  true,
                                        my_hash:                  { first_layer: { nested_layer: 1 } },
                                        my_time:                  current_time,
                                        my_enum:                  :Yes,
                                        my_float:                 1.1,
                                        my_nested_class:          nested_attr_with_int,
                                        nested_aggregate_classes: [nested_attr_with_int, nested_attr_with_string])
        expected_search_hit_body = {
          "rehydration_class" => "DummyElasticSearchModel",
          "query_types"       => ["DummyElasticSearchModel"],
          "my_string"         => "Hello",
          "my_bool"           => true,
          "my_hash"           => "{\"first_layer\":{\"nested_layer\":1}}",
          "my_time"           => current_time.utc.iso8601,
          "my_float"          => 1.1,
          "my_enum"           => "Yes",
          "my_nested_class" => {
            "nested_int_field"  => 100,
            "nested_hash_field" => "{\"a\":1}",
            "nested_bool_class" => {
              "nested_bool" => true
            }
          },
          "data_schema_version"      => "1.0",
          "nested_aggregate_classes" => [
            {
              "nested_int_field" => 100,
              "nested_hash_field" => "{\"a\":1}",
              "nested_bool_class" => {
                "nested_bool" => true
              }
            },
            {
              "nested_string_field" => "nested",
              "nested_hash_field" => "{}",
              "nested_bool_class" => {
                "nested_bool" => true
              }
            }
          ]
        }
        expect(refresh_and_find_search_hit["_source"]).to eq(expected_search_hit_body)
      end
    end

    context ".insert!" do
      before(:each) do
        @default_fields = { "my_string" => "Hello", "my_bool" => false,
                            "data_schema_version" => "1.0",
                            "rehydration_class"   => "DummyElasticSearchModel",
                            "query_types"         => ["DummyElasticSearchModel"] }
      end

      it "takes a squashed model_hash and index and inserts it as a document into Elasticsearch and returns a response" do
        dummy_model = DummyElasticSearchModel.new(my_string: "Hello")

        expect(DummyElasticSearchModel.where.models.count).to eq(0)

        response = DummyElasticSearchModel.insert!(dummy_model.deep_squash_to_store,
                                                   dummy_model.index_name)
        refresh_index
        expect(DummyElasticSearchModel.where.models.count).to eq(1)
        expect(response.dig("_shards", "successful")).to eq(1)
      end

      it "raises an exception if the insert fails" do
        dummy_connection = Elasticsearch::Client.new
        dummy_model = DummyElasticSearchModel.new(my_string: "Hello")

        expect(DummyElasticSearchModel).to receive(:client_connection).and_return(dummy_connection)

        error_response = { "_shards" => { "total" => 2, "successful" => 0, "failed" => 1 } }
        expect(dummy_connection).to receive(:index).and_return(error_response)

        expected_error = "Error creating elasticsearch model. Body: {\"rehydration_class\"=>\"DummyElasticSearchModel\", "\
                         "\"query_types\"=>[\"DummyElasticSearchModel\"], \"my_string\"=>\"Hello\", \"my_bool\"=>false, \"my_hash\"=>\"{}\", "\
                         "\"data_schema_version\"=>\"1.0\"}. Response: {\"_shards\"=>{\"total\"=>2, \"successful\"=>0, \"failed\"=>1}}"
        expect { DummyElasticSearchModel.insert!(dummy_model.deep_squash_to_store, dummy_model.index_name) }
          .to raise_error(ElasticsearchModels::Base::CreateError, expected_error)
      end

      it "raises an exception if a hash is not passed in as the first argument" do
        dummy_model = DummyElasticSearchModel.new(my_string: "Hello")
        expect(dummy_model.class).to_not eq(Hash)

        expect { DummyElasticSearchModel.insert!(dummy_model, dummy_model.index_name) }
          .to raise_error(ArgumentError, "body_hash must be of type Hash, was of type DummyElasticSearchModel.")
      end
    end

    context ".where" do
      it "filters by index and type" do
        dummy_model1 = DummyElasticSearchModel.create!(my_string: "Hello")
        dummy_model2 = DummyElasticSearchModel.create!(my_string: "Hello2")
        refresh_index

        query_response = DummyElasticSearchModel.where
        expect(query_response.models.count).to eq(2)
        expect(query_response.models.sort.map(&:to_store)).to eq([dummy_model1, dummy_model2].sort.map(&:to_store))
      end

      it "filters across multiple indices if provided" do
        clear_and_create_index(index: DummyUniqueIndexModel.index_name)
        DummyElasticSearchModel.create!(my_string: "Hello", my_other_string: "Goodbye")
        DummyElasticSearchModel.create!(my_string: "Exclude this one")
        DummyUniqueIndexModel.create!(my_string: "Hello")
        DummyUniqueIndexModel.create!(my_string: "Exclude this one too")
        refresh_index
        refresh_index(index_name: DummyUniqueIndexModel.index_name)

        query_response = DummyElasticSearchModel.where(my_string: "Hello")
        expect(query_response.models.count).to eql(1)
        expect(query_response.models.first.my_other_string).to eql("Goodbye")

        multi_index_response = DummyElasticSearchModel.where(
          my_string: "Hello",
          _indices: [DummyElasticSearchModel.index_name, DummyUniqueIndexModel.index_name]
        )
        expect(multi_index_response.models.count).to eql(2)
      end

      it "fixes up the schema for the model if data_schema_version does not match the current value" do
        dummy_model = DummyElasticSearchModel.create!(my_string: "Hello")
        expect(dummy_model.my_other_string).to be_nil

        document_id = refresh_and_find_search_hit["_id"]
        @elasticsearch_test_client.update(index: DummyElasticSearchModel.index_name,
                                          type:  "ElasticsearchModel",
                                          id:    document_id,
                                          body:  { doc: { data_schema_version: "0.5" } })

        refresh_index
        queried_model = DummyElasticSearchModel.where.models.first
        expect(queried_model.my_other_string).to eq("Hello")
      end

      it "does not update the schema version if the model was saved at the correct version" do
        DummyElasticSearchModel.create!(my_string: "Hello")

        expect_any_instance_of(DummyElasticSearchModel).to_not receive(:fixup_schema)
        refresh_index
        expect(DummyElasticSearchModel.where.models.first.my_string).to eq("Hello")
      end

      it "allows class names to be swapped during rehydration" do
        DummyReplacedModel.create!(my_string: "Hello4", my_other_string: "Goodbye")
        refresh_index
        query_response = DummyElasticSearchModel.where
        expect(query_response.models.count).to eq(1)
        expect(query_response.models.first.class.name).to eq("DummySub1BModel")
        expect(query_response.models.first.my_other_string).to eq("Goodbye")
      end

      it "allows classes to define alternate search terms in the case of model changes" do
        DummyReplacedModel.create!(my_string: "Hello4", my_other_string: "Goodbye")
        refresh_index
        query_response = DummySub1BModel.where
        expect(query_response.models.count).to eq(1)
        expect(query_response.models.first.class.name).to eq("DummySub1BModel")
        expect(query_response.models.first.my_other_string).to eq("Goodbye")
      end

      context "ignore unavailable indexes" do
        before(:each) do
          @missing_index_name = "non_existent_index"
          expect(@elasticsearch_test_client.indices.exists?(index: @missing_index_name)).to eq(false)
        end

        it "by default raises an error if attempting to search an index that doesn't exist" do
          expected_error = Elasticsearch::Transport::Transport::Errors::NotFound
          expect { DummyElasticSearchModel.where(_indices: [@missing_index_name]) }.to raise_error(expected_error)
        end

        it "does not raise an error if attempting to search an index that doesn't exist but _ignore_available option is true"  do
          expect { DummyElasticSearchModel.where(_indices: [@missing_index_name], _ignore_unavailable: true) }.to_not raise_error
        end
      end

      context "with inheritance" do
        before(:each) do
          DummyElasticSearchModel.create!(my_string: "Hello", my_other_string: "Goodbye")
          DummySub1AModel.create!(my_string: "Hello2", my_dummy_sub_attr: 42)
          DummySub2AModel.create!(my_string: "Hello3", my_dummy_sub_attr: 42)
          DummySub1BModel.create!(my_string: "Hello4", my_other_string: "Goodbye")
          refresh_index
        end

        it "filters on models of the current class and all subclasses" do
          query_response = DummyElasticSearchModel.where
          expect(query_response.models.count).to eq(4)

          first_query = DummyElasticSearchModel.where(my_other_string: "Goodbye").models
          expect(first_query.count).to eq(2)

          expect(first_query.select { |model| model.type == "DummyElasticSearchModel" }.count).to eq(1)
          expect(first_query.select { |model| model.type == "DummySub1BModel" }.count).to eq(1)

          second_query = DummyElasticSearchModel.where(my_dummy_sub_attr: 42).models
          expect(second_query.count).to eq(2)
          expect(second_query.select { |model| model.type == "DummySub1AModel" }.count).to eq(1)
          expect(second_query.select { |model| model.type == "DummySub2AModel" }.count).to eq(1)
        end

        it "does not get hits from documents of the super class" do
          query_response = DummySub1AModel.where.models
          expect(query_response.count).to eq(2)
          expect(query_response.select { |model| model.type == "DummySub1AModel" }.count).to eq(1)
          expect(query_response.select { |model| model.type == "DummySub2AModel" }.count).to eq(1)

          check_no_super_class_query = DummySub1AModel.where(my_string: "Hello").models
          expect(check_no_super_class_query.count).to eq(0)

          check_no_same_level_query = DummySub1AModel.where(my_string: "Hello4").models
          expect(check_no_same_level_query.count).to eq(0)
        end
      end

      context "pagination and sorting" do
        before(:each) do
          @time = Time.now - 1.day
          @dummy_models =
            (1..50).map do |i|
              DummyElasticSearchModel.create!(my_string: "Hello", my_int: i, my_time: @time + i.minutes)
            end
          refresh_index
        end

        context "_size" do
          it "by default returns 10 entries" do
            query_response = DummyElasticSearchModel.where(my_string: "Hello")
            expect(query_response.models.count).to eq(10)
          end

          it "returns 25 entries" do
            query_response = DummyElasticSearchModel.where(my_string: "Hello", _size: 25)
            expect(query_response.models.count).to eq(25)
          end
        end

        context "_sort_by" do
          it "sorts by the specified field ascending" do
            query_response = DummyElasticSearchModel.where(_sort_by: { my_time: :asc })
            expect(query_response.models.count).to eq(10)
            expect(query_response.models.map(&:to_store)).to eq(@dummy_models[0..9].map(&:to_store))
          end

          it "sorts by the specified field descending" do
            query_response = DummyElasticSearchModel.where(_sort_by: { my_time: :desc })
            expect(query_response.models.count).to eq(10)
            expect(query_response.models.map(&:to_store)).to eq(@dummy_models[40..49].reverse.map(&:to_store))
          end

          it "raises an error when attempting to sort by a field that is not mapped" do
            expected_error_snippet = /No mapping found for \[my_non_mapped_field\] in order to sort on/
            expect do
              DummyElasticSearchModel.where(_sort_by: { my_non_mapped_field: :asc })
            end.to raise_error(Elasticsearch::Transport::Transport::Errors::BadRequest, expected_error_snippet)
          end

          it "sorts by a nested field" do
            shared_fields = { nested_string_field: "Hi", nested_hash_field: { a: 1 } }
            nested_attr1 = DummyElasticSearchModel::NestedAggregateAttribute.new(shared_fields.merge(nested_int_field: 100))
            nested_attr2 = DummyElasticSearchModel::NestedAggregateAttribute.new(shared_fields.merge(nested_int_field: 200))

            dummy_model1 = DummyElasticSearchModel.create!(my_string: "Goodbye", my_nested_class: nested_attr1)
            dummy_model2 = DummyElasticSearchModel.create!(my_string: "Goodbye", my_nested_class: nested_attr2)
            refresh_index

            query_response = DummyElasticSearchModel.where(my_string: "Goodbye", _sort_by: { "my_nested_class.nested_int_field" => :desc })
            expect(query_response.models.count).to eq(2)
            expect(query_response.models.map(&:to_store)).to eq([dummy_model2, dummy_model1].map(&:to_store).map(&:deep_stringify_keys))
          end

          it "sorts by multiple fields by the order in which they are defined" do
            dummy_model1 = DummyElasticSearchModel.create!(my_string: "Goodbye", my_time: @time, my_int: 1)
            dummy_model2 = DummyElasticSearchModel.create!(my_string: "Goodbye", my_time: @time - 1.minute, my_int: 1)
            dummy_model3 = DummyElasticSearchModel.create!(my_string: "Goodbye", my_time: @time, my_int: 2)
            refresh_index

            query_response = DummyElasticSearchModel.where(my_string: "Goodbye", _sort_by: [{ my_time: :asc }, { my_int: :desc }])
            expect(query_response.models.count).to eq(3)
            expect(query_response.models.map(&:to_store)).to eq([dummy_model2, dummy_model3, dummy_model1].map(&:to_store))
          end
        end

        context "_from" do
          it "by default starts from spot 0" do
            query_response = DummyElasticSearchModel.where(_sort_by: { my_time: :asc })
            expect(query_response.models.count).to eq(10)
            expect(query_response.models.map(&:to_store)).to eq(@dummy_models[0..9].map(&:to_store))
          end

          it "returns 10 entries starting from spot 42" do
            query_response = DummyElasticSearchModel.where(_from: 32, _sort_by: { my_time: :asc })
            expect(query_response.models.count).to eq(10)
            expect(query_response.models.map(&:to_store)).to eq(@dummy_models[32..41].map(&:to_store))
          end
        end
      end

      context "with a search query" do
        subject(:response) { DummyElasticSearchModel.where(match_conditions.merge(_q: query_conditions)) }
        let(:match_conditions) { {} }

        context "string searching" do
          before(:each) do
            @dummy_model1 = DummyElasticSearchModel.create!(my_string: "Hello")
            @dummy_model2 = DummyElasticSearchModel.create!(my_string: "Hello2")
            @dummy_model3 = DummyElasticSearchModel.create!(my_string: "Hey1", my_other_string: "Hello3")
            @dummy_model4 = DummyElasticSearchModel.create!(my_string: "Hey2", my_other_string: "Hello4")
            @dummy_model5 = DummyElasticSearchModel.create!(my_string: "Whatsup")
            refresh_index
          end

          context "alone" do
            let(:query_conditions) { "Hello" }

            it "returns all matching entries" do
              expect_response_models_match(response.models, [@dummy_model1, @dummy_model2, @dummy_model3, @dummy_model4])
            end
          end

          context "scoped to a field" do
            let(:query_conditions) { { my_other_string: "Hello" } }

            it "returns all matching entries" do
              expect_response_models_match(response.models, [@dummy_model3, @dummy_model4])
            end
          end

          context "with must match attributes" do
            let(:query_conditions) { { my_string: "Hey" } }
            let(:match_conditions) { { my_other_string: "Hello3" } }

            it "returns all matching entries" do
              expect_response_models_match(response.models, [@dummy_model3])
            end
          end
        end

        context "numeric searching" do
          before(:each) do
            @dummy_model1 = DummyElasticSearchModel.create!(my_string: "required", my_int: 10, my_float: 15.5)
            @dummy_model2 = DummyElasticSearchModel.create!(my_string: "required", my_int: 3, my_other_string: "1.21")
            @dummy_model3 = DummyElasticSearchModel.create!(my_string: "required", my_float: 1.21, my_int: 3)
            @dummy_model4 = DummyElasticSearchModel.create!(my_string: "1.21", my_other_string: "10")
            @dummy_model5 = DummyElasticSearchModel.create!(my_string: "required", my_decimal: 1.21, my_int: 3)
            refresh_index
          end

          context "alone" do
            let(:query_conditions) { 10 }

            it "returns all matching entries" do
              expect_response_models_match(response.models, [@dummy_model1, @dummy_model4])
            end
          end

          context "scoped to a field" do
            let(:query_conditions) { { my_decimal: 1.21 } }

            it "returns all matching entries" do
              expect_response_models_match(response.models, [@dummy_model5])
            end
          end

          context "with must match attributes" do
            let(:query_conditions) { 3 }
            let(:match_conditions) { { my_other_string: "1.21" } }

            it "returns all matching entries" do
              expect_response_models_match(response.models, [@dummy_model2])
            end
          end
        end

        context "range searching" do
          before(:each) do
            @dummy_model1 = DummyElasticSearchModel.create!(my_string: "required", my_int: 10, my_float: 15.5)
            @dummy_model2 = DummyElasticSearchModel.create!(my_string: "required", my_int: 3)
            @dummy_model3 = DummyElasticSearchModel.create!(my_string: "required", my_time: Time.new(2010, 1, 2))
            refresh_index
          end

          context "alone" do
            let(:query_conditions) { 3..10 }

            it "returns all matching entries" do
              skip("Semaphore's version of Elasticsearch does not support Full Text Query of Ranges") if ENV["SEMAPHORE_CI_ELASTICSEARCH"].present?
              expect_response_models_match(response.models, [@dummy_model1, @dummy_model2])
            end
          end

          context "scoped to a field" do
            let(:query_conditions) { { my_time: Date.new(2010, 1, 1)..Date.new(2010, 1, 3) } }

            it "returns all matching entries" do
              expect_response_models_match(response.models, [@dummy_model3])
            end
          end

          context "with must match attributes" do
            let(:query_conditions) { 1..10 }
            let(:match_conditions) { { my_float: 15.5 } }

            it "returns all matching entries" do
              expect_response_models_match(response.models, [@dummy_model1])
            end
          end
        end

        context "nil searching" do
          before(:each) do
            @dummy_model1 = DummyElasticSearchModel.create!(my_string: "Whatsup")
            @dummy_model2 = DummyElasticSearchModel.create!(my_string: "Whatsup", my_other_string: "hey there")
            @dummy_model3 = DummyElasticSearchModel.create!(my_string: "Hello")
            refresh_index
          end

          let(:query_conditions) { { my_string: "Whatsup" } }
          let(:match_conditions) { { my_other_string: nil } }

          it "returns matching entries with missing attribute" do
            expect_response_models_match(response.models, [@dummy_model1])
          end
        end
      end

      context "must match attributes (AND)" do
        it "filters by _id" do
          dummy_model = DummyElasticSearchModel.create!(my_string: "Hello")
          DummyElasticSearchModel.create!(my_string: "Hello2")
          refresh_index

          query_response = DummyElasticSearchModel.where(_id: dummy_model._id)
          expect(query_response.models.count).to eq(1)
          expect(query_response.models.first.to_store).to eq(dummy_model.to_store)
        end

        it "filters by matching string" do
          dummy_model = DummyElasticSearchModel.create!(my_string: "Hello")
          DummyElasticSearchModel.create!(my_string: "Hello2")
          refresh_index

          query_response = DummyElasticSearchModel.where(my_string: "Hello")
          expect(query_response.models.count).to eq(1)
          expect(query_response.models.first.to_store).to eq(dummy_model.to_store)
        end

        it "filters by matching int" do
          dummy_model = DummyElasticSearchModel.create!(my_string: "Hello", my_int: 1)
          DummyElasticSearchModel.create!(my_string: "Hello", my_int: 2)
          refresh_index

          query_response = DummyElasticSearchModel.where(my_int: 1)
          expect(query_response.models.count).to eq(1)
          expect(query_response.models.first.to_store).to eq(dummy_model.to_store)
        end

        it "filters by matching boolean" do
          dummy_model = DummyElasticSearchModel.create!(my_string: "Hello", my_bool: false)
          DummyElasticSearchModel.create!(my_string: "Hello", my_bool: true)
          refresh_index

          query_response = DummyElasticSearchModel.where(my_bool: false)
          expect(query_response.models.count).to eq(1)
          expect(query_response.models.first.to_store).to eq(dummy_model.to_store)
        end

        it "filters by matching enum" do
          dummy_model = DummyElasticSearchModel.create!(my_string: "Hello", my_enum: :Maybe)
          DummyElasticSearchModel.create!(my_string: "Hello", my_enum: :No)
          refresh_index

          query_response = DummyElasticSearchModel.where(my_enum: :Maybe)
          expect(query_response.models.count).to eq(1)
          expect(query_response.models.first.to_store).to eq(dummy_model.to_store)
        end

        it "filters by matching nested class" do
          nested_bool_true  = DummyElasticSearchModel::NestedAggregateAttribute::NestedBoolAttribute.new(nested_bool: true)
          nested_bool_false = DummyElasticSearchModel::NestedAggregateAttribute::NestedBoolAttribute.new(nested_bool: false)

          shared_fields = { nested_int_field: 100, nested_string_field: "Hi", nested_hash_field: { a: 1 } }
          nested_attr1 = DummyElasticSearchModel::NestedAggregateAttribute.new(shared_fields.merge(nested_bool_class: nested_bool_true))
          nested_attr2 = DummyElasticSearchModel::NestedAggregateAttribute.new(shared_fields.merge(nested_bool_class: nested_bool_false))

          dummy_model = DummyElasticSearchModel.create!(my_string: "Hello", my_nested_class: nested_attr1)
          DummyElasticSearchModel.create!(my_string: "Hello", my_nested_class: nested_attr2)
          refresh_index

          # Querying keys in JSON hashes is not supported
          where_params = shared_fields.merge(nested_bool_class: { nested_bool: true }) - [:nested_hash_field]

          query_response = DummyElasticSearchModel.where(my_nested_class: where_params)
          expect(query_response.models.count).to eq(1)
          expect(query_response.models.first.to_store).to eq(dummy_model.to_store.deep_stringify_keys)
        end

        it "filters by matching float" do
          dummy_model = DummyElasticSearchModel.create!(my_string: "Hello", my_float: 1.1)
          DummyElasticSearchModel.create!(my_string: "Hello", my_float: 2.1)
          refresh_index

          query_response1 = DummyElasticSearchModel.where(my_float: 1.1)
          expect(query_response1.models.count).to eq(1)
          expect(query_response1.models.first.to_store).to eq(dummy_model.to_store)

          query_response2 = DummyElasticSearchModel.where(my_float: 1.10)
          expect(query_response2.models.count).to eq(1)
          expect(query_response2.models.first.to_store).to eq(dummy_model.to_store)
        end

        it "filters by matching decimal" do
          dummy_model = DummyElasticSearchModel.create!(my_string: "Hello", my_decimal: BigDecimal(5))
          DummyElasticSearchModel.create!(my_string: "Hello", my_decimal: BigDecimal(1))
          refresh_index

          query_response1 = DummyElasticSearchModel.where(my_decimal: BigDecimal(5))
          expect(query_response1.models.count).to eq(1)
          expect(query_response1.models.first.to_store).to eq(dummy_model.to_store)
        end
      end

      context "must match attribute within range (AND)" do
        it "filters by int range" do
          dummy_model = DummyElasticSearchModel.create!(my_string: "Hello", my_int: 5)
          DummyElasticSearchModel.create!(my_string: "Hello", my_int: 1)
          DummyElasticSearchModel.create!(my_string: "Hello", my_int: 10)
          DummyElasticSearchModel.create!(my_string: "Hello")
          refresh_index

          query_response1 = DummyElasticSearchModel.where(my_int: Range.new(4, 6))
          expect(query_response1.models.count).to eq(1)
          expect(query_response1.models.first.to_store).to eq(dummy_model.to_store)

          query_response2 = DummyElasticSearchModel.where(my_int: Range.new(5, 5))
          expect(query_response2.models.count).to eq(1)
          expect(query_response2.models.first.to_store).to eq(dummy_model.to_store)

          query_response3 = DummyElasticSearchModel.where(my_int: Range.new(6, 4))
          expect(query_response3.models.count).to eq(0)
        end

        it "filters by datetime range" do
          current_time = Time.now
          dummy_model = DummyElasticSearchModel.create!(my_string: "Hello", my_time: current_time)

          current_time_diff = 3.minutes
          DummyElasticSearchModel.create!(my_string: "Hello", my_time: current_time - current_time_diff)
          DummyElasticSearchModel.create!(my_string: "Hello", my_time: current_time + current_time_diff)
          DummyElasticSearchModel.create!(my_string: "Hello")
          refresh_index

          range_time_diff = 2.minutes + 59.seconds
          query_response1 = DummyElasticSearchModel.where(my_time: Range.new(current_time - range_time_diff, current_time + range_time_diff))
          expect(query_response1.models.count).to eq(1)
          expect(query_response1.models.first.to_store).to eq(dummy_model.to_store)

          query_response2 = DummyElasticSearchModel.where(my_time: Range.new(current_time, current_time))
          expect(query_response2.models.count).to eq(1)
          expect(query_response2.models.first.to_store).to eq(dummy_model.to_store)

          query_response3 = DummyElasticSearchModel.where(my_time: Range.new(current_time + range_time_diff, current_time - range_time_diff))
          expect(query_response3.models.count).to eq(0)
        end

        it "filters by float range" do
          dummy_model = DummyElasticSearchModel.create!(my_string: "Hello", my_float: 1.50)
          DummyElasticSearchModel.create!(my_string: "Hello", my_float: 1.15)
          DummyElasticSearchModel.create!(my_string: "Hello", my_float: 1.85)
          DummyElasticSearchModel.create!(my_string: "Hello")
          refresh_index

          query_response1 = DummyElasticSearchModel.where(my_float: Range.new(1.49, 1.51))
          expect(query_response1.models.count).to eq(1)
          expect(query_response1.models.first.to_store).to eq(dummy_model.to_store)

          query_response2 = DummyElasticSearchModel.where(my_float: Range.new(1.5, 1.5))
          expect(query_response2.models.count).to eq(1)
          expect(query_response2.models.first.to_store).to eq(dummy_model.to_store)

          query_response3 = DummyElasticSearchModel.where(my_float: Range.new(1.51, 1.49))
          expect(query_response3.models.count).to eq(0)
        end

        it "filters by decimal range" do
          dummy_model = DummyElasticSearchModel.create!(my_string: "Hello", my_decimal: BigDecimal(5))
          DummyElasticSearchModel.create!(my_string: "Hello", my_decimal: BigDecimal(1))
          DummyElasticSearchModel.create!(my_string: "Hello", my_decimal: BigDecimal(10))
          DummyElasticSearchModel.create!(my_string: "Hello")
          refresh_index

          query_response1 = DummyElasticSearchModel.where(my_decimal: Range.new(BigDecimal(4), BigDecimal(6)))
          expect(query_response1.models.count).to eq(1)
          expect(query_response1.models.first.to_store).to eq(dummy_model.to_store)

          query_response2 = DummyElasticSearchModel.where(my_decimal: Range.new(BigDecimal(5), BigDecimal(5)))
          expect(query_response2.models.count).to eq(1)
          expect(query_response2.models.first.to_store).to eq(dummy_model.to_store)

          query_response3 = DummyElasticSearchModel.where(my_decimal: Range.new(BigDecimal(6), BigDecimal(4)))
          expect(query_response3.models.count).to eq(0)
        end

        it "filters by nested class int range" do
          shared_fields = { nested_string_field: "Hi" }
          nested_attr1 = DummyElasticSearchModel::NestedAggregateAttribute.new(shared_fields.merge(nested_int_field: 5))
          nested_attr2 = DummyElasticSearchModel::NestedAggregateAttribute.new(shared_fields.merge(nested_int_field: 1))
          nested_attr3 = DummyElasticSearchModel::NestedAggregateAttribute.new(shared_fields.merge(nested_int_field: 10))
          nested_attr4 = DummyElasticSearchModel::NestedAggregateAttribute.new(shared_fields)

          dummy_model = DummyElasticSearchModel.create!(my_string: "Hello", my_nested_class: nested_attr1)
          DummyElasticSearchModel.create!(my_string: "Hello", my_nested_class: nested_attr2)
          DummyElasticSearchModel.create!(my_string: "Hello", my_nested_class: nested_attr3)
          DummyElasticSearchModel.create!(my_string: "Hello", my_nested_class: nested_attr4)
          refresh_index

          query_response1 = DummyElasticSearchModel.where(my_nested_class: shared_fields.merge(nested_int_field: (4..6)))
          expect(query_response1.models.count).to eq(1)
          expect(query_response1.models.first.to_store).to eq(dummy_model.to_store.deep_stringify_keys)

          query_response2 = DummyElasticSearchModel.where(my_nested_class: shared_fields.merge(nested_int_field: (5..5)))
          expect(query_response2.models.count).to eq(1)
          expect(query_response2.models.first.to_store).to eq(dummy_model.to_store.deep_stringify_keys)

          query_response3 = DummyElasticSearchModel.where(my_nested_class: shared_fields.merge(nested_int_field: (6..4)))
          expect(query_response3.models.count).to eq(0)
        end
      end

      context "should match attributes (OR)" do
        it "filters by multiple _id's" do
          dummy_model1 = DummyElasticSearchModel.create!(my_string: "Hello")
          dummy_model2 = DummyElasticSearchModel.create!(my_string: "Hello2")
          DummyElasticSearchModel.create!(my_string: "Hello3")
          refresh_index

          query_response = DummyElasticSearchModel.where(_id: [dummy_model1._id, dummy_model2._id])
          expect(query_response.models.count).to eq(2)
          expect(query_response.models.sort.map(&:to_store)).to eq([dummy_model1, dummy_model2].sort.map(&:to_store))
        end

        it "filters by attributes based on multiple possible values" do
          dummy_model1 = DummyElasticSearchModel.create!(my_string: "Hello")
          dummy_model2 = DummyElasticSearchModel.create!(my_string: "Goodbye")
          DummyElasticSearchModel.create!(my_string: "What's up?")
          refresh_index

          query_response = DummyElasticSearchModel.where(my_string: ["Hello", "Goodbye"])
          expect(query_response.models.count).to eq(2)
          expect(query_response.models.sort.map(&:to_store)).to eq([dummy_model1, dummy_model2].sort.map(&:to_store))
        end

        it "filters by attributes based on multiple possible values for multiple fields" do
          dummy_model1 = DummyElasticSearchModel.create!(my_string: "Hello", my_int: 1)
          dummy_model2 = DummyElasticSearchModel.create!(my_string: "Goodbye", my_int: 2)

          DummyElasticSearchModel.create!(my_string: "Hi", my_int: 1)
          DummyElasticSearchModel.create!(my_string: "Hi", my_int: 2)
          DummyElasticSearchModel.create!(my_string: "Hello", my_int: 3)
          DummyElasticSearchModel.create!(my_string: "Goodbye", my_int: 3)
          DummyElasticSearchModel.create!(my_string: "What's up?")
          refresh_index

          query_response = DummyElasticSearchModel.where(my_string: ["Hello", "Goodbye"], my_int: [1, 2])
          expect(query_response.models.count).to eq(2)
          expect(query_response.models.sort.map(&:to_store)).to eq([dummy_model1, dummy_model2].sort.map(&:to_store))
        end
      end

      context "combining should and must match attributes (AND with OR)" do
        it "filters by multiple _id's along with other attributes" do
          dummy_model1 = DummyElasticSearchModel.create!(my_string: "Hello", my_int: 1)
          dummy_model2 = DummyElasticSearchModel.create!(my_string: "Hello2", my_int: 1)
          DummyElasticSearchModel.create!(my_string: "Hello3", my_int: 1)
          dummy_model4 = DummyElasticSearchModel.create!(my_string: "Hello", my_int: 2)
          refresh_index

          query_response = DummyElasticSearchModel.where(_id:       [dummy_model1, dummy_model2, dummy_model4].map(&:_id),
                                                         my_string: ["Hello", "Hello2", "Hello3"],
                                                         my_int:    1)
          expect(query_response.models.count).to eq(2)
          expect(query_response.models.sort.map(&:to_store)).to eq([dummy_model1, dummy_model2].sort.map(&:to_store))
        end

        it "filters by attributes based on multiple possible values (including ranges) along with specified must match values" do
          time = Time.now
          successful_query_fields = { my_string: "Hello", my_int: 150, my_enum: :Yes, my_float: 1.0, my_time: time }

          dummy_model1 = DummyElasticSearchModel.create!(my_string: "Hello", my_int: 150, my_enum: :Yes, my_float: 1.0, my_time: time)
          dummy_model2 = DummyElasticSearchModel.create!(my_string: "Goodbye", my_int: 1, my_enum: :Yes, my_float: 1.0, my_time: time)

          DummyElasticSearchModel.create!(successful_query_fields.merge(my_string: "Hi"))
          DummyElasticSearchModel.create!(successful_query_fields.merge(my_int: "2"))
          DummyElasticSearchModel.create!(successful_query_fields.merge(my_enum: :No))
          DummyElasticSearchModel.create!(successful_query_fields.merge(my_float: 1.5))
          DummyElasticSearchModel.create!(successful_query_fields.merge(my_time: time - 1.hour))
          DummyElasticSearchModel.create!(my_string: "Hi")
          DummyElasticSearchModel.create!(my_string: "Hi", my_hash: { a: { b: 1, c: 2 } })
          DummyElasticSearchModel.create!(my_string: "Hi", my_hash: { a: { b: 1, c: 3 } })
          refresh_index

          query_response = DummyElasticSearchModel.where(my_string: ["Hello", "Goodbye"],
                                                         my_int:    [1, Range.new(100, 200)],
                                                         my_enum:   :Yes,
                                                         my_float:  1.0,
                                                         my_time:   Range.new(time - 5.minutes, time + 5.minutes))
          expect(query_response.models.count).to eq(2)
          expect(query_response.models.sort.map(&:to_store)).to eq([dummy_model1, dummy_model2].sort.map(&:to_store))
        end
      end
    end

    context ".count" do
      it "returns count of documents that match simple query params" do
        DummyElasticSearchModel.create!(my_string: "Hello", my_int: 1)
        DummyElasticSearchModel.create!(my_string: "Hello2", my_int: 1)
        DummyElasticSearchModel.create!(my_string: "Hello3", my_int: 1)
        DummyElasticSearchModel.create!(my_string: "Hello", my_int: 2)
        refresh_index

        expect(DummyElasticSearchModel.count(my_string: "Hello")).to eq(2)
      end

      it "returns the count of documents matching dynamic query params" do
        time = Time.now
        successful_query_fields = { my_string: "Hello", my_int: 150, my_enum: :Yes, my_float: 1.0, my_time: time }

        DummyElasticSearchModel.create!(my_string: "Hello", my_int: 150, my_enum: :Yes, my_float: 1.0, my_time: time) # Should be returned
        DummyElasticSearchModel.create!(my_string: "Goodbye", my_int: 1, my_enum: :Yes, my_float: 1.0, my_time: time) # Should be returned

        DummyElasticSearchModel.create!(successful_query_fields.merge(my_string: "Hi"))
        DummyElasticSearchModel.create!(successful_query_fields.merge(my_int: "2"))
        DummyElasticSearchModel.create!(successful_query_fields.merge(my_enum: :No))
        DummyElasticSearchModel.create!(successful_query_fields.merge(my_float: 1.5))
        DummyElasticSearchModel.create!(successful_query_fields.merge(my_time: time - 1.hour))
        DummyElasticSearchModel.create!(my_string: "Hi")
        DummyElasticSearchModel.create!(my_string: "Hi", my_hash: { a: { b: 1, c: 2 } })
        DummyElasticSearchModel.create!(my_string: "Hi", my_hash: { a: { b: 1, c: 3 } })
        refresh_index

        count = DummyElasticSearchModel.count(my_string: ["Hello", "Goodbye"],
                                              my_int:    [1, Range.new(100, 200)],
                                              my_enum:   :Yes,
                                              my_float:  1.0,
                                              my_time:   Range.new(time - 5.minutes, time + 5.minutes))
        expect(count).to eq(2)
      end

      it "raises an error when including the _size param" do
        expect do
          DummyElasticSearchModel.count(my_string: ["Hello", "Goodbye"], _size: 10)
        end.to raise_error(ArgumentError, "URL parameter 'size' is not supported")
      end

      it "raises an error when including the _from param" do
        expect do
          DummyElasticSearchModel.count(my_string: ["Hello", "Goodbye"], _from: 10)
        end.to raise_error(ArgumentError, "URL parameter 'from' is not supported")
      end

      it "raises an error when including the _sort_by param" do
        expect do
          DummyElasticSearchModel.count(my_string: ["Hello", "Goodbye"], _sort_by: { my_time: :asc })
        end.to raise_error(Elasticsearch::Transport::Transport::Errors::BadRequest, /request does not support \[sort\]/)
      end

      context "ignore unavailable indexes" do
        before(:each) do
          @missing_index_name = "non_existent_index"
          expect(@elasticsearch_test_client.indices.exists?(index: @missing_index_name)).to eq(false)
        end

        it "by default raises an error if attempting to search an index that doesn't exist" do
          expected_error = Elasticsearch::Transport::Transport::Errors::NotFound
          expect { DummyElasticSearchModel.count(_indices: [@missing_index_name]) }.to raise_error(expected_error)
        end

        it "does not raise an error if attempting to search an index that doesn't exist but _ignore_available option is true"  do
          expect { DummyElasticSearchModel.count(_indices: [@missing_index_name], _ignore_unavailable: true) }.to_not raise_error
        end
      end
    end

    describe ".distinct_values" do
      subject(:distinct_values) { DummyElasticSearchModel.distinct_values(field, options) }
      let(:field) { "my_string.keyword" }
      let(:options) do
        {
          additional_fields: additional_fields,
          order:             order,
          size:              size,
          partition:         partition,
          num_partitions:    num_partitions,
          where:             where
        }.compact
      end
      let(:additional_fields) { }
      let(:order) { }
      let(:size) { }
      let(:partition) { }
      let(:num_partitions) { }
      let(:where) { }

      before :each do
        DummyElasticSearchModel.create!(my_string: "Hey", my_int: 0, my_bool: true)
        DummyElasticSearchModel.create!(my_string: "Hello", my_int: 1)
        DummyElasticSearchModel.create!(my_string: "This is a test", my_int: 2)
        DummyElasticSearchModel.create!(my_string: "This is a test", my_int: 2)
        DummyElasticSearchModel.create!(my_string: "Hello", my_int: 3, my_bool: true)
        DummyElasticSearchModel.create!(my_string: "Hello again", my_int: 4, my_bool: true)
        DummyElasticSearchModel.create!(my_string: "How are you?", my_other_string: "found by fuzzy matching", my_int: 5)

        refresh_index
      end

      context "when field is not aggregateable" do
        let(:field) { "my_string" }

        it "raises Elasticsearch BadRequest" do
          error = raise_error(Elasticsearch::Transport::Transport::Errors::BadRequest, /Fielddata is disabled on text fields by default/)
          expect { distinct_values }.to error
        end
      end

      context "field provided is a string" do
        it "returns all distinct values for the provided field in hash form" do
          expect(distinct_values).to eq("my_string.keyword" => ["Hello", "This is a test", "Hello again", "Hey", "How are you?"])
        end
      end

      context "field provided is empty" do
        let(:field) { "" }

        it "returns ArgumentError if not provided with a string" do
          expect { distinct_values }.to raise_error(ArgumentError, "field must be a present String")
        end
      end

      context "field provided is not a string" do
        let(:field) { {} }

        it "returns ArgumentError if not provided with a string" do
          expect { distinct_values }.to raise_error(ArgumentError, "field must be a present String")
        end
      end

      context "with :additional_fields option" do
        let(:additional_fields) { ["my_int", "my_other_string.keyword"] }

        it "returns all distinct values with nested values in hash form" do
          # { field => { "response1" => [...], "response2" => [...] } }
          expected_values = {
            "my_string.keyword" => {
              "This is a test" => {
                "my_int" => [2],
                "my_other_string.keyword" => []
              },
              "How are you?" => {
                "my_int" => [5],
                "my_other_string.keyword" => ["found by fuzzy matching"]
              },
              "Hey" => {
                "my_int" => [0],
                "my_other_string.keyword" => []
              },
              "Hello" => {
                "my_int" => [1, 3],
                "my_other_string.keyword" => []
              },
              "Hello again" => {
                "my_int" => [4],
                "my_other_string.keyword" => []
              }
            }
          }
          expect(distinct_values).to eq(expected_values)
        end

        context "but not all fields are present" do
          let(:additional_fields) { ["my_int", ""] }

          it "raises ArgumentError if any of the values provided are not strings" do
            expect { distinct_values }.to raise_error(ArgumentError, "additional_fields must all be present Strings")
          end
        end

        context "but not all fields are strings" do
          let(:additional_fields) { ["my_int", 123] }

          it "raises ArgumentError if any of the values provided are not strings" do
            expect { distinct_values }.to raise_error(ArgumentError, "additional_fields must all be present Strings")
          end
        end
      end

      context "with :size option" do
        let(:size) { 2 }

        it "returns only that number of distinct fields" do
          expect(distinct_values).to eq("my_string.keyword" => ["Hello", "This is a test"])
        end
      end

      context "with :order option" do
        context "as a String" do
          let(:order) { "_term" }

          it "orders response by provided option" do
            expect(distinct_values).to eq("my_string.keyword" => ["This is a test", "How are you?", "Hey", "Hello again", "Hello"])
          end
        end

        context "as an Array with a single element defining sort field" do
          let(:order) { ["_term"] }

          it "orders response by provided option" do
            expect(distinct_values).to eq("my_string.keyword" => ["This is a test", "How are you?", "Hey", "Hello again", "Hello"])
          end
        end

        context "as a Hash" do
          let(:order) { { "_term" => "asc" } }

          it "orders response by provided option" do
            expect(distinct_values).to eq("my_string.keyword" => ["Hello", "Hello again", "Hey", "How are you?", "This is a test"])
          end
        end

        context "as an array with multiple order terms" do
          let(:order) { [{ "_count" => "desc" }, { "_term" => "desc" }] }

          it "orders response by provided option" do
            expect(distinct_values).to eq("my_string.keyword" => ["This is a test", "Hello", "How are you?", "Hey", "Hello again"])
          end
        end

        context "as an invalid option" do
          let(:order) { "not orderable" }

          it "raises Elasticsearch error" do
            error = raise_error(Elasticsearch::Transport::Transport::Errors::InternalServerError, /Unknown aggregation \[not orderable\]/)
            expect { distinct_values }.to error
          end
        end
      end

      context "with :partition provided alone" do
        let(:partition) { 0 }

        it "raises Elasticsearch error" do
          error = raise_error(
            Elasticsearch::Transport::Transport::Errors::BadRequest,
            /Missing \[num_partitions\] parameter for partition-based include/
          )
          expect { distinct_values }.to error
        end
      end

      context "with :num_partitions provided alone" do
        let(:num_partitions) { 10 }

        it "raises Elasticsearch error" do
          error = raise_error(Elasticsearch::Transport::Transport::Errors::BadRequest, /Missing \[partition\] parameter for partition-based include/)
          expect { distinct_values }.to error
        end
      end

      context "with :partition and :num_partitions provided" do
        let(:partition) { 0 }
        let(:num_partitions) { 2 }

        it "allows for partitioned responses" do
          expect(distinct_values).to eq("my_string.keyword" => ["Hello", "This is a test", "Hello again", "How are you?"])
          expect(DummyElasticSearchModel.distinct_values(field, options.merge(partition: 1))).to eq("my_string.keyword" => ["Hey"])
        end
      end

      context "with :where param" do
        context "provided with a search query (_q param)" do
          let(:where) { { _q: "fuzzy" } }

          it "filters down responses" do
            expect(distinct_values).to eq("my_string.keyword" => ["How are you?"])
          end
        end

        context "provided with AND/OR matches" do
          let(:where) { { my_int: 1..4, my_bool: true } }

          it "filters down matches" do
            expect(distinct_values).to eq("my_string.keyword" => ["Hello", "Hello again"])
          end
        end
      end
    end
  end
end
