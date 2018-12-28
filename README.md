# ElasticsearchModels
Model representation for Elasticsearch documents based on Aggregate

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'elasticsearch_models'
```

And then execute:

```shell
$ bundle
```

Or install it yourself as:

```shell
$ gem install elasticsearch_models
```

## Elasticsearch Setup (Required)
See [SETUP.md]("https://github.com/Invoca/elasticsearch_models/blob/master/SETUP.md") for steps on installing and working with Elasticsearch locally.

## Usage
All classes that you want to store as documents should inherit from `ElasticsearchModels::Base` (which inherits from `ElasticsearchModels::Aggregate`). All classes (including nested classes) should inherit from `ElasticsearchModels::Aggregate`.

### Full Examples
For complete example usage, see [the spec for ElasticsearchModels::Base]("https://github.com/Invoca/elasticsearch_models/blob/master/spec/base_spec.rb").

### Creating a model
```ruby
class DummyElasticSearchModel < ElasticsearchModels::Base
  class NestedClass < ElasticsearchModels::Aggregate
    attribute :nested_string_field, :string
    attribute :nested_int_field,    :integer
    attribute :nested_hash_field,   :hash
  end

  attribute :my_string,       :string,    required: true
  attribute :my_time,         :datetime
  attribute :my_int,          :integer
  attribute :my_bool,         :boolean,   default: false
  attribute :my_nested_class, NestedClass

  class << self
    def index_name
      ElasticsearchClusterSpecHelper::ELASTICSEARCH_TEST_INDEX
    end

    def client_connection
      @client_connection ||= Elasticsearch::Client.new(host: "127.0.0.1", port: ENV["ELASTICSEARCH_TEST_PORT"] || 9250, scheme: "http")
    end
  end
end
```

```ruby
  DummyElasticSearchModel.create!(my_string: "Hi", my_nested_class: DummyElasticSearchModel::NestedClass.new(nested_int_field: 5, nested_hash_field: { "a" => 1, "b" => 2 }))
```

### Querying for a model
Queries return a `ElasticsearchModels::QueryResponse` which will contain `raw_response`, `models`, and `errors`.
* `raw_response`: Full response from elasticsearch query.
* `models`: Rehydrated models from the query response (based on `_type`).
* `errors`: Errors that occurred when attempting to rehydrate models.

#### Query by Elasticsearch document id or attributes

```ruby
# Query by elasticsearch document id
DummyElasticSearchModel.where(_id: "1234567890")

# Query by attributes that all must match
DummyElasticSearchModel.where(my_string: "Hi")
DummyElasticSearchModel.where(my_string: "Hi", my_int: 2)

# Query by attributes that must be within a range
DummyElasticSearchModel.where(my_int: (1..10))
DummyElasticSearchModel.where(my_string: "Hi", my_time: (Time.local(2018, 12, 12)..Time.local(2018, 12, 13)))

# Query by attributes that should match at least 1 value (can include ranges)
DummyElasticSearchModel.where(my_string: ["Hi", "Bye"])
DummyElasticSearchModel.where(my_string: ["Hi", "Bye"], my_int: [1, 2])
DummyElasticSearchModel.where(my_int: [1, (5..10)])

# Query by attributes that must match and attributes that should match at least 1 value
DummyElasticSearchModel.where(my_string: "Hi", my_int: [1, 2])

# Query by attributes that must match and attributes that should match at least 1 value (can include ranges)
DummyElasticSearchModel.where(my_string: "Hi", my_int: [1, (5..10)])

# Query by matching nested classes and or hash fields
DummyElasticSearchModel.where(my_nested_class: { nested_hash_field: { a: 1, b: 2 } })
```

#### Adding sorting to queries

```ruby
# Sort by an attribute
DummyElasticSearchModel.where(my_string: "Hi", _sort_by: { my_time: :asc })

# Sort by multiple attributes
DummyElasticSearchModel.where(_sort_by: [{ my_int: :desc }, { my_time: :asc }])

# Sort by nested classes and hash fields
DummyElasticSearchModel.where(_sort_by: [{ "my_nested_class.nested_hash_field.a.b" => :desc })
```

#### Adding pagination to queries
By default, 10 entries are returned from spot 0.

```ruby
# Return 25 entries starting from spot 32
DummyElasticSearchModel.where(_size: 25, _from: 32)
```
