# frozen_string_literal: true

class ElasticsearchModels::Aggregate < Aggregate::Base
  class << self
    def i18n_scope
      :activerecord
    end

    def aggregate_db_storage_type
      :elasticsearch
    end
  end
end
