# frozen_string_literal: true

class ElasticsearchModels::Query::Response
  class ParseError < StandardError
    attr_reader :original_exception

    def initialize(message, original_exception)
      @original_exception = original_exception
      super(message)
    end
  end

  attr_reader :models, :raw_response, :errors, :aggregations

  def initialize(raw_response, class_factory = nil)
    @raw_response    = raw_response
    @aggregations    = raw_response["aggregations"]
    @class_factory   = class_factory
    @models, @errors = parse_raw_response
  end

  private

  def parse_raw_response
    parsed_models = []
    parsed_errors = []

    if (hits = @raw_response.dig("hits", "hits")).present?
      hits.each do |hit|
        parsed_hit = parse_hit(hit)
        parsed_models << parsed_hit[:model]
        parsed_errors << parsed_hit[:error]
      end
    end

    [parsed_models.compact, parsed_errors.compact]
  end

  def parse_hit(hit)
    if (klass = @class_factory.model_class_from_name(hit["_source"]["rehydration_class"]))
      { model: klass.from_store(hit) }
    end
  rescue => ex
    { error: ParseError.new("Error rehydrating model from query response hit. Hit: #{hit}.", ex) }
  end
end
