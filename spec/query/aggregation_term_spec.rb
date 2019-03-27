# frozen_string_literal: true

RSpec.describe ElasticsearchModels::Query::AggregationTerm do
  let(:options) { { field: field, size: size, order: order, partition: partition, num_partitions: num_partitions }.compact }
  let(:field) { "some.field.keyword" }
  let(:size) { }
  let(:order) { }
  let(:partition) { }
  let(:num_partitions) { }

  describe "#initialize" do
    subject(:aggregation) { ElasticsearchModels::Query::AggregationTerm.new(options) }

    it { should be }
    it { should have_attributes(field: field) }

    context "when field is provided" do
      context "as empty string" do
        let(:field) { "" }

        it "raises ArgumentError" do
          expect { aggregation }.to raise_error(ArgumentError, "field must be provided")
        end
      end

      context "as nil" do
        subject(:aggregation) { ElasticsearchModels::Query::AggregationTerm.new(options.merge(field: nil)) }

        it "raises ArgumentError" do
          expect { aggregation }.to raise_error(ArgumentError, "field must be provided")
        end
      end
    end

    context "when size is provided" do
      let(:size) { 10_000 }
      it { should be }
    end

    context "when order is provided" do
      context "as a string" do
        let(:order) { "_key" }
        it { should be }
      end

      context "as an array" do
        let(:order) { ["_key"] }
        it { should be }
      end

      context "as a hash" do
        let(:order) { { "_key" => "asc" } }
        it { should be }
      end

      context "as anything else" do
        let(:order) { 1 }
        it "should raise an ArgumentError" do
          expect { aggregation }.to raise_error(ArgumentError, "unexpected value for order: got 1")
        end
      end
    end

    context "when partition is provided" do
      let(:partition) { 10 }
      it { should be }
    end

    context "when num_partitions is provided" do
      let(:num_partitions) { 10 }
      it { should be }
    end
  end

  describe "#term" do
    subject(:term) { aggregation.term }
    let(:aggregation) { ElasticsearchModels::Query::AggregationTerm.new(options) }
    let(:expected_term) { { field => { terms: expected_inner_terms } } }
    let(:expected_inner_terms) { { field: "some.field.keyword" } }

    it { should eq(expected_term) }

    context "when size is provided" do
      let(:size) { 10_000 }
      let(:expected_inner_terms) { { field: "some.field.keyword", size: 10_000 } }

      it "includes the size in the inner terms" do
        expect(term).to eq(expected_term)
      end
    end

    context "when order is provided" do
      context "as a string" do
        let(:order) { "_key" }
        let(:expected_inner_terms) { { field: "some.field.keyword", order: [{ "_key" => "desc" }] } }

        it "orders by provided field with a default sort direction" do
          expect(term).to eq(expected_term)
        end
      end

      context "as a hash" do
        let(:order) { { "_key" => "asc" } }
        let(:expected_inner_terms) { { field: "some.field.keyword", order: [{ "_key" => "asc" }] } }

        it "orders by provided field with provided sort direction" do
          expect(term).to eq(expected_term)
        end
      end

      context "as an array" do
        let(:order) { ["_key", { "_count" => "asc" }] }
        let(:expected_inner_terms) { { field: "some.field.keyword", order: [{ "_key" => "desc" }, { "_count" => "asc" }] } }

        it "orders by all provided orderings" do
          expect(term).to eq(expected_term)
        end
      end
    end

    context "partition is provided" do
      let(:partition) { 1 }
      let(:expected_inner_terms) { { field: "some.field.keyword", include: { partition: 1 } } }

      it "nests partition under include key within inner terms" do
        expect(term).to eq(expected_term)
      end
    end

    context "num_partitions is provided" do
      let(:num_partitions) { 1 }
      let(:expected_inner_terms) { { field: "some.field.keyword", include: { num_partitions: 1 } } }

      it "nests num_partitions under include key" do
        expect(term).to eq(expected_term)
      end
    end

    context "partition and num_partitions are provided within inner terms" do
      let(:partition) { 1 }
      let(:num_partitions) { 1 }
      let(:expected_inner_terms) { { field: "some.field.keyword", include: { partition: 1, num_partitions: 1 } } }

      it "nests values under include key within inner terms" do
        expect(term).to eq(expected_term)
      end
    end
  end
end
