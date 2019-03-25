# frozen_string_literal: true

module ElasticsearchModels
  module Query
    class Aggregations
      class << self
        def terms_for(condition)
          { aggs: internal_terms_for(condition) }
        end

        private

        def internal_terms_for(condition)
          condition = condition.dup
          case condition
          when String
            term_for_string(condition)
          when Array
            term_for_array(condition)
          when Hash
            term_for_hash(condition)
          else
            raise ArgumentError, "unexpected condition type: got #{condition.inspect}"
          end
        end

        def term_for_string(condition)
          AggregationTerm.new(field: condition).term
        end

        def term_for_array(conditions)
          conditions.flatten.each_with_object({}) do |condition, aggs|
            term  = internal_terms_for(condition)
            field = term.keys.first
            aggs.key?(field) and raise ArgumentError, "duplicate field aggregation provided for #{field.inspect}"
            aggs.merge!(term)
          end
        end

        def term_for_hash(condition)
          sub_aggs = condition.delete(:aggs)
          AggregationTerm.new(condition).term.tap do |agg|
            agg.values.first.merge!(terms_for(sub_aggs)) if sub_aggs
          end
        end
      end
    end
  end
end
