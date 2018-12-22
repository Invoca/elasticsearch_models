# frozen_string_literal: true

RSpec.describe ElasticsearchModels::Aggregate do
  it "inherits from Aggregate::Base" do
    expect(ElasticsearchModels::Aggregate.new.is_a?(Aggregate::Base)).to be(true)
  end

  context ".aggregate_db_storage_type" do
    it "returns :elasticsearch" do
      expect(ElasticsearchModels::Aggregate.aggregate_db_storage_type).to eq(:elasticsearch)
    end
  end
end
