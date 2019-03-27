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
        @order   = Array.wrap(order).flatten.map { |term| order_term(term) }.compact.presence
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
        case order.presence
        when String
          { order => DEFAULT_ORDER_DIRECTION }
        when Hash, nil
          order
        else
          raise ArgumentError, "unexpected value for order: got #{order.inspect}"
        end
      end
    end
  end
end
