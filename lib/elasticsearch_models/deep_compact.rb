# frozen_string_literal: true

module ElasticsearchModels::DeepCompact
  def deep_compact(object)
    case object
    when Hash
      deep_compact_hash(object).presence
    when Array
      deep_compact_array(object).presence
    when TrueClass, FalseClass
      object
    else
      object.presence
    end
  end

  def deep_compact_hash(hash)
    hash.map { |key, value| [key, deep_compact(value)] }.to_h.compact
  end

  def deep_compact_array(array)
    array.map { |item| deep_compact(item) }.compact
  end
end
