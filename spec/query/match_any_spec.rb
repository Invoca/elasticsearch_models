# frozen_string_literal: true

RSpec.describe ElasticsearchModels::Query::MatchAny do
  context "Query::MatchAny" do
    it "returns an array of conditions under a 'should' key" do
      expected_conditions = [
        {
          bool: {
            should: [
              { match_phrase: { a: 1 } },
              { match_phrase: { a: 2 } }
            ],
            minimum_should_match: 1
          }
        }
      ]

      params = { a: [1, 2] }
      expect(ElasticsearchModels::Query::MatchAny.terms_for(params)).to eq(expected_conditions)
    end

    it "returns an array of multiple sets of conditions (with ranges) under a 'should' key" do
      expected_conditions = [
        {
          bool: {
            should: [
              { match_phrase: { a: 1 } },
              { match_phrase: { a: 2 } }
            ],
            minimum_should_match: 1
          }
        },
        {
          bool: {
            should: [
              { match_phrase: { b: 3 } },
              { match_phrase: { b: 4 } },
              { range: { b: { "gte" => 10, "lte" => 20 } } }
            ],
            minimum_should_match: 1
          }
        }
      ]

      params = { a: [1, 2], b: [3, 4, (10..20)] }
      expect(ElasticsearchModels::Query::MatchAny.terms_for(params)).to eq(expected_conditions)
    end

    it "flattens hashes and returns conditions (with ranges) under a 'should' key" do
      expected_conditions = [
        {
          bool: {
            should: [
              { match_phrase: { a: 1 } },
              { match_phrase: { a: 2 } }
            ],
            minimum_should_match: 1
          }
        },
        {
          bool: {
            should: [
              {
                bool: {
                  must: [
                    { match_phrase: { "b.x.y.z" => 3 } },
                    { match_phrase: { "b.x.y.w" => 5 } }
                  ]
                }
              },
              {
                bool: {
                  must: [
                    { match_phrase: { "b.x.y.z" => 3 } },
                    { range: { "b.x.y.g" => { "gte" => 30, "lt" => 50 } } }
                  ]
                }
              },
              { range: { b: { "gte" => 10, "lte" => 20 } } }
            ],
            minimum_should_match: 1
          }
        }
      ]

      params = { a: [1, 2], b: [{ x: { y: { z: 3, w: 5 } } }, { x: { y: { z: 3, g: (30...50) } } }, (10..20)] }
      expect(ElasticsearchModels::Query::MatchAny.terms_for(params)).to eq(expected_conditions)
    end
  end
end
