# frozen_string_literal: true

module ElasticsearchModels
  module Query
    class Builder
      def initialize(**params)
        @indices = params.delete(:_indices)

        @q                  = params.delete(:_q)
        @aggs               = params.delete(:_aggs).presence
        @size               = params.delete(:_size)
        @from               = params.delete(:_from)
        @sort_by            = params.delete(:_sort_by)
        @ignore_unavailable = params.delete(:_ignore_unavailable)

        @params = params.compact
      end

      def search_params
        { index: @indices, size: @size, from: @from, ignore_unavailable: @ignore_unavailable, body: body }.compact
      end

      private

      def body
        [match_query_body, sort_body, aggs_body].reduce(&:merge).presence
      end

      def aggs_body
        if @aggs
          Aggregations.terms_for(@aggs)
        else
          {}
        end
      end

      def search_query
        @search_query ||= QueryString.term_for(@q)
      end

      def match_query_body
        if (terms = match_terms).present?
          { query: { bool: { must: terms } } }
        else
          {}
        end
      end

      def match_terms
        flattened_params = Helper.flatten_hash_with_full_key_paths(@params)
        match_any_params, match_all_params = flattened_params.partition { |_k, v| v.is_a?(Array) }

        [
          (MatchCondition.query_string(search_query) if search_query),
          *MatchAll.terms_for(match_all_params),
          *MatchAny.terms_for(match_any_params)
        ].compact
      end

      def sort_body
        { sort: Array.wrap(@sort_by).presence }.compact
      end
    end
  end
end
