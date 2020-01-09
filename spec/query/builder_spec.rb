# frozen_string_literal: true

RSpec.describe ElasticsearchModels::Query::Builder do
  def expected_query_body(bool_body: nil, sort_by_inner_body: nil, aggs_inner_body: nil)
    query_body   = bool_body.present? ? { query: { bool: bool_body } } : {}
    sort_by_body = sort_by_inner_body.present? ? { sort: sort_by_inner_body } : {}
    aggs_body = aggs_inner_body.present? ? { aggs: aggs_inner_body } : {}
    @default_expected_params.merge(body: [query_body, sort_by_body, aggs_body].reduce(&:merge))
  end

  def new_builder(**params)
    ElasticsearchModels::Query::Builder.new({ _indices: "index" }.merge(params))
  end

  context "Query::Builder" do
    before(:each) do
      @default_expected_params = { index: "index" }
    end

    context "nil searching" do
      it "formats nil term as missing field for search params body" do
        expected_bool_body = {
          must: [
            { bool: { must_not: { exists: { field: "empty_term" } } } }
          ]
        }
        expected_params = expected_query_body(bool_body: expected_bool_body)
        expect(new_builder(empty_term: nil).search_params).to eq(expected_params)
      end
    end

    context "text searching" do
      it "includes the query_string in search_params when _q is given" do
        expected_bool_body = {
          must: [
            query_string: {
              query: '(*text AND search*)'
            }
          ]
        }
        expect(new_builder(_q: "text search").search_params).to eq(expected_query_body(bool_body: expected_bool_body))
      end
    end

    context "pagination and sorting" do
      it "includes _size when given" do
        expected_params = @default_expected_params.merge(size: 100)
        expect(new_builder(_size: 100).search_params).to eq(expected_params)
      end

      it "includes _from when given" do
        expected_params = @default_expected_params.merge(from: 99)
        expect(new_builder(_from: 99).search_params).to eq(expected_params)
      end

      it "includes _ignore_unavailable when given" do
        expected_params = @default_expected_params.merge(ignore_unavailable: true)
        expect(new_builder(_ignore_unavailable: true).search_params).to eq(expected_params)
      end

      context "_sort_by" do
        let(:expected_bool_body) do
          {
            must: [{ match_phrase: { "term1" => true } }]
          }
        end

        it "includes sorting when given" do
          expected_params = expected_query_body(bool_body: expected_bool_body, sort_by_inner_body: [{ term2: :asc }])
          expect(new_builder(term1: true, _sort_by: { term2: :asc }).search_params).to eq(expected_params)
        end

        it "includes multiple _sort_by values when given" do
          sort_by = [{ term2: :asc }, { term3: :desc }, { "term4.term5" => :asc }]
          expected_params = expected_query_body(bool_body: expected_bool_body, sort_by_inner_body: sort_by)
          expect(new_builder(term1: true, _sort_by: sort_by).search_params).to eq(expected_params)
        end
      end
    end

    context "must match terms (AND)" do
      it "formats terms for search params body" do
        bool_body = {
          must: [
            { match_phrase: { "term1" => true } },
            { match_phrase: { "term2" => "Hello" } }
          ]
        }
        expected_params = expected_query_body(bool_body: bool_body)
        expect(new_builder(term1: true, term2: "Hello").search_params).to eq(expected_params)
      end

      it "formats range term for search params body" do
        bool_body = {
          must: [
            { match_phrase: { "term1" => true } },
            { range: { "term2" => { "lte" => 2, "gte" => 1 } } }
          ]
        }
        expected_params = expected_query_body(bool_body: bool_body)
        expect(new_builder(term1: true, term2: (1..2)).search_params).to eq(expected_params)
      end

      it "formats range term for search params body with exclusive end" do
        bool_body = {
          must: [
            { match_phrase: { "term1" => true } },
            { range: { "term2" => { "lt" => 5, "gte" => 1 } } }
          ]
        }
        expected_params = expected_query_body(bool_body: bool_body)
        expect(new_builder(term1: true, term2: (1...5)).search_params).to eq(expected_params)
      end

      it "formats range term with float for search params body with exclusive end" do
        bool_body = {
          must: [
            { match_phrase: { "term1" => true } },
            { range: { "term2" => { "lt" => 5.7, "gte" => 1.2 } } }
          ]
        }
        expected_params = expected_query_body(bool_body: bool_body)
        min = 1.2
        max = 5.7
        expect(new_builder(term1: true, term2: (min...max)).search_params).to eq(expected_params)
      end

      it "flattens nested hashes with full key paths" do
        bool_body = {
          must: [
            { match_phrase: { "term1" => true } },
            { match_phrase: { "term2.a.b" => 1 } },
            { match_phrase: { "term2.a.c" => 2 } }
          ]
        }
        expected_params = expected_query_body(bool_body: bool_body)
        expect(new_builder(term1: true, term2: { a: { b: 1, c: 2 } }).search_params).to eq(expected_params)
      end

      it "formats range term in flattened nested hashes with full key paths" do
        bool_body = {
          must: [
            { match_phrase: { "term1" => true } },
            { match_phrase: { "term2.a.b" => 1 } },
            { range: { "term2.a.c" => { "lte" => 2, "gte" => 1 } } }
          ]
        }
        expected_params = expected_query_body(bool_body: bool_body)
        expect(new_builder(term1: true, term2: { a: { b: 1, c: (1..2) } }).search_params).to eq(expected_params)
      end
    end

    context "should match terms (OR)" do
      it "formats terms for search params body" do
        bool_body = {
          must: [
            {
              bool: {
                should: [
                  { match_phrase: { "term1" => "Hello" } },
                  { match_phrase: { "term1" => "Goodbye" } }
                ],
                minimum_should_match: 1
              }
            },
            {
              bool: {
                should: [
                  { match_phrase: { "term2" => 1 } },
                  { match_phrase: { "term2" => 2 } }
                ],
                minimum_should_match: 1
              }
            }
          ]
        }
        expected_params = expected_query_body(bool_body: bool_body)
        expect(new_builder(term1: ["Hello", "Goodbye"], term2: [1, 2]).search_params).to eq(expected_params)
      end

      it "formats range term for search params body" do
        bool_body = {
          must: [
            {
              bool: {
                should: [
                  { match_phrase: { "term1" => 1 } },
                  { range: { "term1" => { "lte" => 50, "gte" => 20 } } }
                ],
                minimum_should_match: 1
              }
            }
          ]
        }
        expected_params = expected_query_body(bool_body: bool_body)
        expect(new_builder(term1: [1, (20..50)]).search_params).to eq(expected_params)
      end

      it "flattens nested hashes with full key paths" do
        bool_body = {
          must: [
            {
              bool: {
                should: [
                  { match_phrase: { "term1" => 1 } },
                  { match_phrase: { "term1" => 2 } }
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
                        { match_phrase: { "term2.a.b" => 1 } },
                        { match_phrase: { "term2.a.c.d" => 4 } }
                      ]
                    },
                  },
                  {
                    bool: {
                      must: [
                        { match_phrase: { "term2.a.b" => 2 } },
                        { match_phrase: { "term2.a.c" => 2 } }
                      ]
                    }
                  }
                ],
                minimum_should_match: 1
              }
            }
          ]
        }
        expected_params = expected_query_body(bool_body: bool_body)
        expect(new_builder(term1: [1, 2], term2: [{ a: { b: 1, c: { d: 4 } } }, { a: { b: 2, c: 2 } }]).search_params).to eq(expected_params)
      end

      it "formats range term in flattened nested hashes with full key paths" do
        bool_body = {
          must: [
            {
              bool: {
                should: [
                  { match_phrase: { "term1" => 1 } },
                  { match_phrase: { "term1" => 2 } }
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
                        { match_phrase: { "term2.a.b" => 1 } },
                        { range: { "term2.a.c.d" => { "lte" => 2, "gte" => 1 } } }
                      ]
                    },
                  },
                  {
                    bool: {
                      must: [
                        { match_phrase: { "term2.a.b" => 2 } },
                        { match_phrase: { "term2.a.c" => 2 } }
                      ]
                    }
                  }
                ],
                minimum_should_match: 1
              }
            }
          ]
        }
        expected_params = expected_query_body(bool_body: bool_body)
        expect(new_builder(term1: [1, 2], term2: [{ a: { b: 1, c: { d: (1..2) } } }, { a: { b: 2, c: 2 } }]).search_params).to eq(expected_params)
      end
    end

    context "must and should match terms (AND and OR)" do
      it "formats terms" do
        bool_body = {
          must: [
            { match_phrase: { "term1" => true } },
            { match_phrase: { "term2" => "Hello" } },
            {
              bool: {
                should: [
                  { match_phrase: { "term3" => 1 } },
                  { match_phrase: { "term3" => 2 } }
                ],
                minimum_should_match: 1
              }
            },
            {
              bool: {
                should: [
                  { match_phrase: { "term4" => :a } },
                  { match_phrase: { "term4" => :b } }
                ],
                minimum_should_match: 1
              }
            }
          ]
        }
        expected_params = expected_query_body(bool_body: bool_body)
        expect(new_builder(term1: true, term2: "Hello", term3: [1, 2], term4: [:a, :b]).search_params).to eq(expected_params)
      end

      it "formats range term for search params body" do
        bool_body = {
          must: [
            { match_phrase: { "term1" => true } },
            { range: { "term2" => { "lte" => 2, "gte" => 1 } } },
            {
              bool: {
                should: [
                  { match_phrase: { "term3" => 1 } },
                  { range: { "term3" => { "lte" => 4, "gte" => 3 } } }
                ],
                minimum_should_match: 1
              }
            },
            {
              bool: {
                should: [
                  { match_phrase: { "term4" => :a } },
                  { match_phrase: { "term4" => :b } }
                ],
                minimum_should_match: 1
              }
            }
          ]
        }
        expected_params = expected_query_body(bool_body: bool_body)
        expect(new_builder(term1: true, term2: (1..2), term3: [1, (3..4)], term4: [:a, :b]).search_params).to eq(expected_params)
      end

      it "flattens nested hashes with full key paths and ranges" do
        bool_body = {
          must: [
            { match_phrase: { "term1" => true } },
            { match_phrase: { "term2.a.b" => 1 } },
            { match_phrase: { "term2.a.c" => 2 } },
            {
              bool: {
                should: [
                  { match_phrase: { "term3" => 1 } },
                  {
                    bool: {
                      must: [
                        { match_phrase: { "term3.a.b" => 2 } },
                        { range: { "term3.a.c.d" => { "lte" => 2, "gte" => 1 } } }
                      ]
                    }
                  }
                ],
                minimum_should_match: 1
              }
            },
            {
              bool: {
                should: [
                  { match_phrase: { "term4" => :a } },
                  { match_phrase: { "term4" => :b } }
                ],
                minimum_should_match: 1
              }
            }
          ]
        }
        expected_params = expected_query_body(bool_body: bool_body)
        params = { term1: true, term2: { a: { b: 1, c: 2 } }, term3: [1, { a: { b: 2, c: { d: (1..2) } } }], term4: [:a, :b] }
        expect(new_builder(params).search_params).to eq(expected_params)
      end
    end

    context "with _aggs provided" do
      subject(:search_params) { new_builder(search_options).search_params }
      let(:search_options) { { _aggs: _aggs } }
      let(:_aggs) { "some.field.keyword" }
      let(:expected_inner_aggs) do
        {
          "some.field.keyword" => {
            terms: {
              field: "some.field.keyword"
            }
          }
        }
      end

      it "includes aggs in body" do
        expect(search_params).to eq(expected_query_body(aggs_inner_body: expected_inner_aggs))
      end

      context "and a search query" do
        let(:search_options) { { _aggs: _aggs, _q: "text search" } }

        it "includes the query_string in bool body with aggregations built" do
          expected_bool_body = {
            must: [
              query_string: {
                query: '(*text AND search*)'
              }
            ]
          }
          expect(search_params).to eq(expected_query_body(aggs_inner_body: expected_inner_aggs, bool_body: expected_bool_body))
        end
      end
    end
  end
end
