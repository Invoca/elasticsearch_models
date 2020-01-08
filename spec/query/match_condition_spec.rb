# frozen_string_literal: true

RSpec.describe ElasticsearchModels::Query::MatchCondition do
  context "Query::MatchCondition" do
    it "returns key and value within match_phrase for non-range and non-hash values" do
      expect(ElasticsearchModels::Query::MatchCondition.term_for(:a, 1)).to eq(match_phrase: { a: 1 })
    end

    context "nil" do
      it "returns a match_phrase expecting the value not to exist" do
        expected_term = { bool: {must_not: { exists: {field: :a } } } }
        expect(ElasticsearchModels::Query::MatchCondition.term_for(:a, nil)).to eq(expected_term)
      end
    end

    context "range" do
      it "returns range for inclusive end" do
        expected_term = { range: { a: { "gte" => 1, "lte" => 5 } } }
        expect(ElasticsearchModels::Query::MatchCondition.term_for(:a, (1..5))).to eq(expected_term)
      end

      it "returns range for exclusive end" do
        expected_term = { range: { a: { "gte" => 1, "lt" => 5 } } }
        expect(ElasticsearchModels::Query::MatchCondition.term_for(:a, (1...5))).to eq(expected_term)
      end

      it "returns range for floats" do
        expected_term = { range: { a: { "gte" => 1.1, "lte" => 5.8 } } }

        min = 1.1
        max = 5.8
        expect(ElasticsearchModels::Query::MatchCondition.term_for(:a, (min..max))).to eq(expected_term)
      end

      it "converts time to iso8601 and returns range" do
        time = Time.utc(2018, 12, 27, 20, 10).in_time_zone("Pacific Time (US & Canada)")
        expect(time.iso8601).to eq("2018-12-27T12:10:00-08:00")
        expect(time.zone).to eq("PST")

        min_time = time - 300
        max_time = time + 300

        expected_term = { range: { a: { "gte" => "2018-12-27T20:05:00Z", "lte" => "2018-12-27T20:15:00Z" } } }
        expect(ElasticsearchModels::Query::MatchCondition.term_for(:a, (min_time..max_time))).to eq(expected_term)
      end
    end

    context "hash" do
      it "flattens hash value and returns an array of all expected conditions to match" do
        expected_term = {
          bool: {
            must: [
              { match_phrase: { "a.b.c" => 2 } },
              { match_phrase: { "a.b.d" => 3 } },
              { range: { "a.b.e.f" => { "gte" => 1, "lte" => 5 } } }
            ]
          }
        }
        value = { b: { c: 2, d: 3, e: { f: (1..5) } } }
        expect(ElasticsearchModels::Query::MatchCondition.term_for(:a, value)).to eq(expected_term)
      end
    end

    describe ".query_string" do
      subject(:condition) { ElasticsearchModels::Query::MatchCondition.query_string(query_string) }
      let(:query_string) { "some_search_term" }

      it "returns nested hash to hold the query_string" do
        expected_term = {
          query_string: {
            query: query_string
          }
        }
        expect(condition).to eq(expected_term)
      end
    end
  end
end
