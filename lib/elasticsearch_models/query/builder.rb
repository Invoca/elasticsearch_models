# frozen_string_literal: true

module ElasticsearchModels
  module Query
    class Builder
      def initialize(index_name, **params)
        @index_name = index_name

        @size       = params.delete(:_size)
        @from       = params.delete(:_from)
        @sort_by    = params.delete(:_sort_by)

        @params = params.compact
      end

      def search_params
        { index: @index_name, size: @size, from: @from, body: search_body }.compact
      end

      private

      def search_body
        [query_body, sort_by_body].reduce(&:merge).presence
      end

      def query_body
        if (terms = match_terms).present?
          { query: { bool: { must: terms } } }
        else
          {}
        end
      end

      def match_terms
        flattened_params = Helper.flatten_hash_with_full_key_paths(@params)
        match_any_params, match_all_params = flattened_params.partition { |_k, v| v.is_a?(Array) }

        (MatchAll.terms_for(match_all_params) + MatchAny.terms_for(match_any_params)).compact
      end

      def sort_by_body
        { sort: Array.wrap(@sort_by).presence }.compact
      end
    end
  end
end
