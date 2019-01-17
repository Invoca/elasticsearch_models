# frozen_string_literal: true

RSpec.describe ElasticsearchModels::Query::Response do
  INDEX = "test_index"

  class DummyKlass < ElasticsearchModels::Base
    attribute :my_string, :string
    attribute :my_bool,   :boolean
    attribute :my_int,    :integer
    attribute :my_enum,   :enum, limit: [:Hello, :Goodbye]

    def self.index
      INDEX
    end
  end

  def create_search_hit(body_params: {}, search_hit_params: {})
    {
      "_index" => INDEX,
      "_type"  => "ElasticsearchModel",
      "_id"    => "i5JhrmcBUU6q7YBzawfu",
      "_score" => 4.2685113,
      "_source" => {
        "my_string"          => "Hello",
        "my_bool"            => false,
        "my_int"             => 150,
        "rehydration_class"  => "DummyKlass",
      }.merge(body_params)
    }.merge(search_hit_params)
  end

  def form_raw_response(hits)
    {
      "took"      => 3,
      "timed_out" => false,
      "_shards"   => {
        "total"      => 5,
        "successful" => 5,
        "skipped"    => 0,
        "failed"     => 0
      },
      "hits" => {
        "total"     => hits.count,
        "max_score" => 4.2685113,
        "hits"      => hits
      }
    }
  end

  context "Query::Response" do
    context "#raw_response" do
      it "stores the full query response " do
        response = form_raw_response([create_search_hit])
        expect(ElasticsearchModels::Query::Response.new(response).raw_response).to eq(response)
      end
    end

    context "#models" do
      it "returns rehydrated models" do
        search_hits    = [create_search_hit, create_search_hit(body_params: { "my_string" => "Hi", "my_enum" => "Goodbye", "my_bool" => true })]
        query_response = ElasticsearchModels::Query::Response.new(form_raw_response(search_hits))

        expect(query_response.errors).to be_empty
        expect(query_response.models.count).to eq(2)

        expected_metadata_fields = { "_id" => "i5JhrmcBUU6q7YBzawfu", "_index" => "test_index", "query_types" => [],
                                     "_type" => "ElasticsearchModel", "rehydration_class" => "DummyKlass" }
        expected_model1_to_store = expected_metadata_fields.merge("my_string" => "Hello", "my_bool" => false, "my_int" => 150, "my_enum" => nil)
        expected_model2_to_store = expected_metadata_fields.merge("my_string" => "Hi", "my_bool" => true, "my_int" => 150, "my_enum" => :Goodbye)

        expect(query_response.models.map(&:class).uniq).to eq([DummyKlass])
        expect(query_response.models.map(&:aggregate_attributes)).to eq([expected_model1_to_store, expected_model2_to_store])
      end

      it "includse metadata fields in the returned rehydrated model" do
        query_response = ElasticsearchModels::Query::Response.new(form_raw_response([create_search_hit]))

        expect(query_response.errors).to be_empty
        expect(query_response.models.count).to eq(1)

        model = query_response.models.first
        expect(model._id).to eq("i5JhrmcBUU6q7YBzawfu")
        expect(model._type).to eq("ElasticsearchModel")
        expect(model._index).to eq("test_index")
      end

      it "returns errors if there's an exception while rehydrating a model and not return that model" do
        search_hits    = [create_search_hit, create_search_hit(body_params: { "rehydration_class" => "invalid class" })]
        query_response = ElasticsearchModels::Query::Response.new(form_raw_response(search_hits))

        expect(query_response.models.count).to eq(1)
        expect(query_response.errors.count).to eq(1)
        expected_error_message = "Error rehydrating model from query response hit. Hit: {\"_index\"=>\"test_index\", "\
                                 "\"_type\"=>\"ElasticsearchModel\", \"_id\"=>\"i5JhrmcBUU6q7YBzawfu\", "\
                                 "\"_score\"=>4.2685113, \"_source\"=>{\"my_string\"=>\"Hello\", \"my_bool\"=>false, "\
                                 "\"my_int\"=>150, \"rehydration_class\"=>\"invalid class\"}}."
        expect(query_response.errors.first.message).to eq(expected_error_message)
        expect(query_response.errors.first.original_exception.is_a?(NameError)).to be(true)
      end
    end
  end
end
