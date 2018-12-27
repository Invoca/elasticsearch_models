# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/time'
require 'active_support/core_ext/array'
require 'active_support/core_ext/hash'

require 'aggregate'
require 'hobo_support'
require 'elasticsearch'

require 'elasticsearch_models/version'
require 'elasticsearch_models/deep_squash'
require 'elasticsearch_models/aggregate'
require 'elasticsearch_models/base'

require 'elasticsearch_models/query/builder'
require 'elasticsearch_models/query/response'
require 'elasticsearch_models/query/helper'
require 'elasticsearch_models/query/match_all'
require 'elasticsearch_models/query/match_any'
require 'elasticsearch_models/query/match_condition'
