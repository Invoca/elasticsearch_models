# frozen_string_literal: true

module ElasticsearchModels
  module Query
    class AggregationTerm
      attr_reader :field, :term

      DEFAULT_ORDER_BY = "_count"
      DEFAULT_ORDER_DIRECTION = "desc"

      def initialize(field:, size: nil, order: nil, partition: nil, num_partitions: nil)
        @field = field.presence or raise ArgumentError, "field must be provided"

        @size    = size
        @order   = order_term(order)
        @include = { partition: partition, num_partitions: num_partitions }.compact.presence
        @term    = _term
      end

      private

      def _term
        {
          field => {
            terms: {
              field:   field,
              size:    @size,
              order:   @order,
              include: @include
            }.compact
          }
        }
      end

      def order_term(order)
        order_by, order_direction =
          case order.presence
          when String
            [order, DEFAULT_ORDER_DIRECTION]
          when Array
            order.size > 2 and raise ArgumentError, "order provided as an Array with more than 2 elements. Expected 1..2"
            [order[0], order[1] || DEFAULT_ORDER_DIRECTION]
          when nil
            [DEFAULT_ORDER_BY, DEFAULT_ORDER_DIRECTION]
          else
            raise ArgumentError, "unexpected value for order: got #{order.inspect}"
          end
        { order_by => order_direction }
      end
    end
  end
end
