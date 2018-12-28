# frozen_string_literal: true

module ElasticsearchModels
  module Query
    class MatchAny
      def self.terms_for(params)
        params.map do |key, value|
          terms_list = value.map { |item| MatchCondition.term_for(key, item) }
          { bool: { should: terms_list, minimum_should_match: 1 } }
        end
      end
    end
  end
end
