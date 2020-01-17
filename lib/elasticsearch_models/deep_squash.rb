# frozen_string_literal: true

module ElasticsearchModels
  module DeepSquash
    def deep_squash(object)
      case object
      when Hash
        deep_squash_hash(object).presence
      when Array
        deep_squash_array(object).presence
      when TrueClass, FalseClass
        object
      else
        object.presence
      end
    end

    def deep_squash_hash(hash)
      hash.map { |key, value| [key, deep_squash(value)] }.to_h.compact
    end

    def deep_squash_array(array)
      array.map { |item| deep_squash(item) }.compact
    end
  end
end
