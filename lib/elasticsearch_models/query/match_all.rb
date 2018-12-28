# frozen_string_literal: true

module ElasticsearchModels
  module Query
    class MatchAll
      def self.terms_for(params, flatten: false)
        params_hash = flatten ? Helper.flatten_hash_with_full_key_paths(params) : params
        params_hash.flat_map { |k, v| MatchCondition.term_for(k, v) }
      end
    end
  end
end
