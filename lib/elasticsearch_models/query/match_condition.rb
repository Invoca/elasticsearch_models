# frozen_string_literal: true

module ElasticsearchModels
  module Query
    class MatchCondition
      class << self
        def term_for(key, value)
          if value.nil?
            { bool: { must_not: { exists: { field: key } } } }
          elsif value.is_a?(Range)
            range_condition(key, value)
          elsif value.is_a?(Hash)
            params = { key => value }
            { bool: { must: MatchAll.terms_for(params, flatten: true) } }
          else
            { match_phrase: { key => value } }
          end
        end

        def query_string(string)
          {
            query_string: {
              query: string
            }
          }
        end

        private

        def range_condition(key, value)
          min = format_range_value(value.first)
          max = format_range_value(value.last)

          less_than_key = value.exclude_end? ? "lt" : "lte"

          { range: { key => { "gte" => min, less_than_key => max } } }
        end

        def format_range_value(range_value)
          if range_value.is_a?(Time)
            range_value.utc.iso8601
          else
            range_value
          end
        end
      end
    end
  end
end
