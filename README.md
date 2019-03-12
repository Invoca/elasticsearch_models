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

Note: `rehydration_class` and `query_types` are fields used internally in `ElasticsearchModels::Base` so they should not be changed.

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

#### Querying with Inheritance
When querying on a super class of an ElasticSearch Model, it will retrieve all matching documents of that class and all sub classes of the super class.
```ruby
# Using the DummyElasticSearchModel from above
class DummySubClassModel < DummyElasticSearchModel; end

a = DummyElasticSearchModel.create!(my_string: "Hello World", my_other_string: "Foobar")
b = DummySubClassModel.create!(my_string: "Hello World", my_other_string: "Baz")
c = DummySubClassModel.create!(my_string: "Goodbye")

DummyElasticSearchModel.where.models
=> Returns [a, b, c]

DummyElasticSearchModel.where(my_string: "Hello World").models
=> Returns [a, b]

DummyElasticSearchModel.where(my_other_string: "Baz").models
=> Returns [b]

DummySubClassModel.where.models
=> Returns [b, c]

DummySubClassModel.where(my_other_string: "Foobar").models
=> Returns []
```

#### Querying on indices
To query on a specific index, add the `_indices` parameter in your query along with the index you wish to query across.

To query across multiple indices, add the `_indices` parameter in your query with an array of the indices you wish to query across.

Not specifying the indices in a query will use the index name returned from `index_name` by the model you are querying.

The intended usecase for this is to allow for querying across multiple indices that are sharded by time.

Note: Names for indices are arbitrary: passing in an index_name into `_indices` that doesn't exist will return 0 documents.
```ruby
class DummyDailyIndexModel < DummyElasticSearchModel
  def index_name
    time.strftime("dummy_daily_index.%Y.%m.%d")
  end
end

# Date created: 01/04/19
a = DummyElasticSearchModel.create!(my_string: "Hello World 1").models
# Date created: 01/05/19
b = DummyDailyIndexModel.create!(my_string: "Hello World 2").models
# Date created: 01/06/19
c = DummyDailyIndexModel.create!(my_string: "Hello World 3").models

# Current Date: 01/06/19
DummyDailyIndexModel.index_name
=> "dummy_daily_index.19.01.06"

DummyDailyIndexModel.where.models
=> Returns [c]

DummyDailyIndexModel.where(_indices: "dummy_daily_index.19.01.04").models
=> Returns [a]

DummyDailyIndexModel.where(_indices: "dummy_daily_index.19.01.05").models
=> Returns [b]

DummyDailyIndexModel.where(_indices: ["dummy_daily_index.19.01.04", "dummy_daily_index.19.01.05"]).models
=> Returns [a, b]

DummyDailyIndexModel.where(_indices: ["dummy_daily_index.19.01.04", "dummy_daily_index.19.01.05", "dummy_daily_index.19.01.06"]).models
=> Returns [a, b, c]

DummyDailyIndexModel.where(_indices: "wrong_index_name").models
=> []
```

### Retrieving Count of Documents
If you only need to query for the count of documents, you can call `.count` with normal query params. The count will be the return value.

Note: You will need to exclude `_size`, `_from`, and `_sort_by` params.

```ruby

DummyElasticSearchModel.count(my_string: "Hi", my_int: 2) # => 2
```
