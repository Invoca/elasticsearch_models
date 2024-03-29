# frozen_string_literal: true

RSpec.describe ElasticsearchModels::Query::Aggregations do
  describe ".terms_for" do
    subject(:terms) { ElasticsearchModels::Query::Aggregations.terms_for(condition) }

    let(:condition) { }

    context "when condition is a String" do
      let(:condition) { "some.field.keyword" }

      it "builds a single aggregation term" do
        expected_terms = {
          aggs: {
            "some.field.keyword" => {
              terms: {
                field: "some.field.keyword"
              }
            }
          }
        }
        expect(terms).to eq(expected_terms)
      end
    end

    context "when condition is an Array" do
      let(:condition) { ["some.field.keyword", "some.field.integer"] }

      context "and a value is a String" do
        it "builds aggregation terms with wide sub aggregations" do
          expected_terms = {
            aggs: {
              "some.field.keyword" => {
                terms: {
                  field: "some.field.keyword"
                }
              },
              "some.field.integer" => {
                terms: {
                  field: "some.field.integer"
                }
              }
            }
          }
          expect(terms).to eq(expected_terms)
        end
      end

      context "and a value is a Hash" do
        let(:condition) { [{ field: "some.field.keyword", size: 10_000, order: "_key" }, "some.field.integer"] }

        it "builds aggregation terms with provided options" do
          expected_terms = {
            aggs: {
              "some.field.keyword" => {
                terms: {
                  field: "some.field.keyword",
                  size:  10_000,
                  order: [{ "_key" => "desc" }]
                }
              },
              "some.field.integer" => {
                terms: {
                  field: "some.field.integer"
                }
              }
            }
          }
          expect(terms).to eq(expected_terms)
        end
      end

      context "and a value is an Array" do
        let(:condition) { ["some.field.keyword", ["some.int", "some.other.int"]] }

        it "should flatten array and build terms" do
          expected_terms = {
            aggs: {
              "some.field.keyword" => {
                terms: {
                  field: "some.field.keyword"
                }
              },
              "some.int" => {
                terms: {
                  field: "some.int"
                }
              },
              "some.other.int" => {
                terms: {
                  field: "some.other.int"
                }
              }
            }
          }
          expect(terms).to eq(expected_terms)
        end
      end

      context "with duplicate fields" do
        let(:condition) { ["some.field.keyword"] * 2 }
        it "raises ArgumentError" do
          expect { terms }.to raise_error(ArgumentError, "duplicate field aggregation provided for \"some.field.keyword\"")
        end
      end
    end

    context "when condition is a Hash" do
      context "and field is not provided" do
        let(:condition) { { size: 10_000 } }
        it "raises an ArgumentError" do
          expect { terms }.to raise_error(ArgumentError, /missing keyword: :?field/)
        end
      end

      context "and field is provided" do
        let(:condition) { { field: "some.field.keyword", size: 10_000, order: "_key" } }

        it "builds aggregation terms with the provided options" do
          expected_terms = {
            aggs: {
              "some.field.keyword" => {
                terms: {
                  field: "some.field.keyword",
                  size: 10_000,
                  order: [{ "_key" => "desc" }]
                }
              }
            }
          }
          expect(terms).to eq(expected_terms)
        end

        context "with aggs option" do
          let(:condition) { { field: "some.field.keyword", size: 10_000, order: "_key", aggs: "some.field.id" } }

          context "and value is a String" do
            it "builds aggregation terms with a single sub aggregation" do
              expected_terms = {
                aggs: {
                  "some.field.keyword" => {
                    terms: {
                      field: "some.field.keyword",
                      size: 10_000,
                      order: [{ "_key" => "desc" }]
                    },
                    aggs: {
                      "some.field.id" => {
                        terms: {
                          field: "some.field.id"
                        }
                      }
                    }
                  }
                }
              }
              expect(terms).to eq(expected_terms)
            end
          end

          context "and value is a Hash" do
            let(:condition) { { field: "some.field.keyword", size: 10_000, order: "_key", aggs: { field: "some.field.id", size: 20 } } }

            it "also builds sub aggregation terms with provided options" do
              expected_terms = {
                aggs: {
                  "some.field.keyword" => {
                    terms: {
                      field: "some.field.keyword",
                      size: 10_000,
                      order: [{ "_key" => "desc" }]
                    },
                    aggs: {
                      "some.field.id" => {
                        terms: {
                          field: "some.field.id",
                          size: 20
                        }
                      }
                    }
                  }
                }
              }
              expect(terms).to eq(expected_terms)
            end
          end

          context "And value is a Hash with missing top level field" do
            let(:condition) { { field: "some.field.keyword", missing: "N/A", size: 10_000, order: "_key", aggs: { field: "some.field.id" } } }

            it "builds aggregation terms with missing field at the top level" do
              expected_terms = {
                aggs: {
                  "some.field.keyword" => {
                    terms: {
                      field: "some.field.keyword",
                      size: 10000,
                      order: [{ "_key" => "desc" }],
                      missing: "N/A"
                    },
                    aggs: {
                      "some.field.id" => {
                        terms: {
                          field: "some.field.id"
                        }
                      }
                    }
                  }
                }
              }
              expect(terms).to eq(expected_terms)
            end
          end

          context "And value is a Hash with missing additional field option" do
            let(:condition) { { field: "some.field.keyword", size: 10_000, order: "_key", aggs: { field: "some.field.id", missing: 1 } } }

            it "also builds sub aggregation terms with provided missing option" do
              expected_terms = {
                aggs: {
                  "some.field.keyword" => {
                    terms: {
                      field: "some.field.keyword",
                      size: 10_000,
                      order: [{ "_key" => "desc" }]
                    },
                        aggs: {
                          "some.field.id" => {
                            terms: {
                              field: "some.field.id",
                              missing: 1
                            }
                          }
                        }
                  }
                }
              }
              expect(terms).to eq(expected_terms)
            end
          end

          context "And value is a Hash with missing top level and additional field" do
            let(:condition) do
              {
                field: "some.field.keyword",
                missing: "N/A", size: 10_000,
                order: "_key",
                aggs: { field: "some.field.id", missing: 1 }
              }
            end

            it "builds aggregation terms with missing field at the top level and in additional aggregations" do
              expected_terms = {
                aggs: {
                  "some.field.keyword" => {
                    terms: {
                      field: "some.field.keyword",
                          size: 10000,
                          order: [{ "_key" => "desc" }],
                          missing: "N/A"
                    },
                        aggs: {
                          "some.field.id" => {
                            terms: {
                              field: "some.field.id",
                                  missing: 1
                            }
                          }
                        }
                  }
                }
              }
              expect(terms).to eq(expected_terms)
            end
          end

          context "and value is an Array" do
            let(:condition) { { field: "some.field.keyword", size: 10_000, order: "_key", aggs: ["some.field.id", "some.field.other"] } }

            it "builds aggregation terms with many sub aggregations" do
              expected_terms = {
                aggs: {
                  "some.field.keyword" => {
                    terms: {
                      field: "some.field.keyword",
                      size: 10_000,
                      order: [{ "_key" => "desc" }]
                    },
                    aggs: {
                      "some.field.id" => {
                        terms: {
                          field: "some.field.id"
                        }
                      },
                      "some.field.other" => {
                        terms: {
                          field: "some.field.other"
                        }
                      }
                    }
                  }
                }
              }
              expect(terms).to eq(expected_terms)
            end
          end
        end
      end

      context "with unexpected options" do
        let(:condition) { { field: "some.field.keyword", invalid: "key" } }

        it "raises an ArgumentError" do
          expect { terms }.to raise_error(ArgumentError, /unknown keyword: :?invalid/)
        end
      end
    end

    context "when condition is anything else" do
      let(:condition) { 1 }

      it "raises an ArgumentError" do
        expect { terms }.to raise_error(ArgumentError, "unexpected condition type: got 1")
      end
    end
  end
end
