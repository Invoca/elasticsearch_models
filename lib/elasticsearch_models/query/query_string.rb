# frozen_string_literal: true

module ElasticsearchModels
  module Query
    class QueryString
      # http://lucene.apache.org/core/3_4_0/queryparsersyntax.html#Escaping%20Special%20Characters
      SPECIAL_CHARACTERS_REGEX = /(#{Regexp.escape('& | ! ( ) { } [ ] ^ " ~ * ?').split('\\ ').join('|')})/

      class << self
        def term_for(condition)
          case condition
          when String
            term_for_string(condition)
          when Numeric, nil
            condition
          when Hash
            term_for_hash(condition)
          when Array
            term_for_array(condition)
          when Range
            term_for_range(condition)
          else
            raise ArgumentError, "#{condition.class} is not a supported search condition type"
          end
        end

        private

        def term_for_string(string)
          unless string.empty?
            "(*#{format_string(string)}*)"
          end
        end

        def term_for_hash(hash)
          flattened_condition = Helper.flatten_hash_with_full_key_paths(hash)
          flattened_condition.map { |key, and_condition| "#{key}:#{term_for(and_condition)}" }.compact.join(" AND ")
        end

        def term_for_array(array)
          condition = array.map { |or_condition| term_for(or_condition) }.compact.join(" OR ")
          "(#{condition})"
        end

        def term_for_range(range)
          # Certain Objects that are useable in a range apparently cannot be iterated over, so if we
          # have a min and max value, we obviously have a non-empty range
          if (min = format_range_value(range.min)) && (max = format_range_value(range.max))
            "[#{min} TO #{max}]"
          end
        end

        def format_range_value(range_value)
          case range_value
          when Date
            range_value.iso8601
          when Time
            range_value.utc.iso8601
          else
            range_value
          end
        end

        def format_string(string)
          string.squeeze(" ").gsub(SPECIAL_CHARACTERS_REGEX, '\\\1').gsub(" ", " AND ")
        end
      end
    end
  end
end
