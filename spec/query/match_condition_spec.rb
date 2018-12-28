# frozen_string_literal: true

RSpec.describe ElasticsearchModels::Query::MatchCondition do
  context "Query::MatchCondition" do
    it "returns key and value within match_phrase for non-range and non-hash values" do
      expect(ElasticsearchModels::Query::MatchCondition.term_for(:a, 1)).to eq(match_phrase: { a: 1 })
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
        time     = Time.local(2018, 12, 27, 12, 10)
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
  end
end
