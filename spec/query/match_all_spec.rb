# frozen_string_literal: true

RSpec.describe ElasticsearchModels::Query::MatchAll do
  context "Query::MatchAll" do
    it "returns an empty array for empty params" do
      expect(ElasticsearchModels::Query::MatchAll.terms_for({})).to eq([])
    end

    it "returns an array of conditions to match" do
      expected_conditions = [
        { match_phrase: { a: 1 } },
        { match_phrase: { b: 2 } },
        { range: { c: { "gte" => 1, "lte" => 5 } } }
      ]
      params = { a: 1, b: 2, c: (1..5) }
      expect(ElasticsearchModels::Query::MatchAll.terms_for(params)).to eq(expected_conditions)
    end

    context "flatten params as true" do
      it "flattens the params hash keys and returns an array of conditions to match" do
        expected_conditions = [
          { match_phrase: { "a.z" => 1 } },
          { match_phrase: { "a.x.y" => 2 } },
          { range: { "a.x.v" => { "gte" => 1, "lte" => 5 } } },
          { match_phrase: { "b" => 2 } }
        ]
        params = { a: { z: 1, x: { y: 2, v: (1..5) } }, b: 2 }
        expect(ElasticsearchModels::Query::MatchAll.terms_for(params, flatten: true)).to eq(expected_conditions)
      end
    end
  end
end
