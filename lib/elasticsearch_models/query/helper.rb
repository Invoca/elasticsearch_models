# frozen_string_literal: true

module ElasticsearchModels
  module Query
    module Helper
      def self.flatten_hash_with_full_key_paths(hash)
        hash.map do |outer_key, outer_value|
          if outer_value.is_a?(Hash)
            flattened_outer_value = flatten_hash_with_full_key_paths(outer_value)
            flattened_outer_value.map do |inner_key, inner_value|
              ["#{outer_key}.#{inner_key}", inner_value]
            end.to_h
          else
            { outer_key.to_s => outer_value }
          end
        end.reduce({}, &:merge)
      end
    end
  end
end
