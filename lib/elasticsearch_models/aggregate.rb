# frozen_string_literal: true

module ElasticsearchModels
  class Aggregate < Aggregate::Base
    class << self
      def i18n_scope
        :activerecord
      end

      def aggregate_db_storage_type
        :elasticsearch
      end

      def datetime_formatter
        method :format_datetime
      end

      def format_datetime(datetime)
        datetime.utc.iso8601(3)
      end
    end
  end
end
