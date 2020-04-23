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

  context ".datetime_formatter" do
    it "returns a method that formats to iso8601 with 3 decimal places" do
      expect(ElasticsearchModels::Aggregate.datetime_formatter.call(Time.at(1_544_657_724.1234))).to eq("2018-12-12T23:35:24.123Z")
    end
  end
end
