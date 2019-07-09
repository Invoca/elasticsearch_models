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

Notes:
* `rehydration_class` and `query_types` are fields used internally in `ElasticsearchModels::Base` so they should not be changed.
* `hash` fields are stored as JSON blobs, meaning they are not queryable and can not be used for sorting. If necessary, use a nested class with named fields.


### Creating a model
_create!_ will build and validate a model and then insert the model into Elasticsearch:
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

### Newing a model (without inserting)
Just like active record, creating a new model will not save it to the database, but you can call save on the model to write it.

```ruby
model = DummyElasticSearchModel.new(my_string: "Hi")
model.save!
```

Unlike active record, you cannot update an existing model.

#### `#new_record?`

`model.new_record?` can be used to determine if a model can be saved or not.

### Inserting a model
_insert!_ allows the ability to insert a model hash to Elasticsearch.

_insert!_ will raise an exception if the first argument passed in is not a Hash

On success, _insert!_ will return the response Elasticsearch gives.

On failure, _insert!_ will raise a _ElasticsearchModels::Base::CreateError_ exception.
```ruby

model = DummyElasticSearchModel.new(my_string: "Hi")
model.validate!

# Success
response = DummyElasticSearchModel.insert!(model.deep_squash_to_store, model.index_name)

# Elasticsearch Failure
DummyElasticSearchModel.insert!(model.deep_squash_to_store, model.index_name)
=> raises ElasticsearchModels::Base::CreateError

# Non-Hash value passed in for first argument
DummyElasticSearchModel.insert!("abc", model.index_name)
=> raises RuntimeError
```

### Querying for a model
Queries return a `ElasticsearchModels::QueryResponse` which will contain `raw_response`, `models`, and `errors`.
* `raw_response`: Full response from elasticsearch query.
* `models`: Rehydrated models from the query response (based on `_type`).
* `errors`: Errors that occurred when attempting to rehydrate models.
* `aggregations`: Raw response for any aggregations included in the search.

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

# Query by matching nested class fields (hashes and nested hashes are not queryable by default)
DummyElasticSearchModel.where(my_nested_class: { nested_int_field: 5 })
```

#### Adding sorting to queries

```ruby
# Sort by an attribute
DummyElasticSearchModel.where(my_string: "Hi", _sort_by: { my_time: :asc })

# Sort by multiple attributes
DummyElasticSearchModel.where(_sort_by: [{ my_int: :desc }, { my_time: :asc }])

# Sort by nested class fields (can not sort by fields in hashes and nested hashes by default)
DummyElasticSearchModel.where(_sort_by: [{ "my_nested_class.nested_hash_field.a.b" => :desc })
```

#### Adding pagination to queries
By default, 10 entries are returned from spot 0.

```ruby
# Return 25 entries starting from spot 32
DummyElasticSearchModel.where(_size: 25, _from: 32)
```

#### Query String searching
By providing the `_q` parameter, you can do Full Text Query String searching.

String searching using the `_q` parameter is fuzzy by default (`*` on both ends of string so you can match in the middle of terms/strings).

As well, search terms that include spaces will `AND` each term instead of the implicit `OR`

e.g. `full text` search string will be converted to the following query string `(*full AND text*)`
```ruby
# Query by full text string searching
DummyElasticSearchModel.where(_q: "Hello")

# Query by fuzzy text searching on a specific field
DummyElasticSearchModel.where(_q: { my_string: "Hello" })

# Query by attributes in a range as well
DummyElasticSearchModel.where(_q: { my_string: "Hi", my_int: 5..10) })

# Query by attributes where at least 1 value matches
DummyElasticSearchModel.where(_q: { my_string: "Hi", my_int: [1, (5..10)] })

# Query by nested class fields (hashes and nested hashes are not queryable by default)
DummyElasticSearchModel.where(_q: { my_nested_class: { nested_string_field: "Hey" })
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

The intended use case for this is to allow for querying across multiple indices that are sharded by time.

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

#### Querying with Aggregations
To query and receive term aggregations back, simply add the `_aggs` parameter to your query along with the term and/or term with options that you like to get an aggregation for.

The default ordering for an aggregation is by the `_count` in `desc` order

Supported Aggregation query params:

**Required Arguments**:
* `field`: the field to do an aggregation on

**Optional Arguments**:
* `size`: the limit on how many terms to return as part of the terms aggregation
* `order`: The ordering for the response
* `partitions`: The current partition to query in (requires `num_partitions` if set)
* `num_partitions`: The amount of partitions to bucket results into (requires `partition` if set)

```ruby
# Aggregate on a single term
# Note: keyword terms are required for text fields that do not have fielddata enabled on the index
DummyElasticSearchModel.where(_aggs: "my_string.keyword")

# Aggregate on a multiple terms
DummyElasticSearchModel.where(_aggs: ["my_string.keyword", "my_int.id"])

# Aggregate on a single field with a limit on the result size
DummyElasticSearchModel.where(_aggs: { field: "my_string.keyword", size: 2 })

# Aggregate on a single field with ordering on a different field (default desc order)
DummyElasticSearchModel.where(_aggs: { field: "my_string.keyword", order: "_key" })

# Aggregate on a single field with ordering on a different field in a different direction
DummyElasticSearchModel.where(_aggs: { field: "my_string.keyword", order: { "_key" => "asc" } })

# Aggregate on a single field with multiple ordering options
DummyElasticSearchModel.where(_aggs: { field: "my_string.keyword", order: ["_key", { "_count" => "asc" }] })

# Aggregate on a single field with sub-aggregations (supports infinite nestings)
DummyElasticSearchModel.where(_aggs: { field: "my_string.keyword", aggs: "my_id" })
```

### Retrieving Count of Documents
If you only need to query for the count of documents, you can call `.count` with normal query params. The count will be the return value.

Note: You will need to exclude `_size`, `_from`, and `_sort_by` params.

```ruby

DummyElasticSearchModel.count(my_string: "Hi", my_int: 2) # => 2
```

### Retrieving Distinct Values for a Field
If you would like to find all of the distinct values for a specific field, you can call `.distinct_values` with normal Aggregation query params.

This method of aggregation supports one layer of sub aggregations only.
```ruby
# Distinct Values for single term
DummyElasticSearchModel.distinct_values("my_string.keyword")

# Distinct Values for single term with a response size limit
DummyElasticSearchModel.distinct_values("my_string.keyword", size: 10)

# Distinct Values for single term with Query filtering
DummyElasticSearchModel.distinct_values("my_string.keyword", where: { my_string: "Alec" } })

# Distinct Values for single term Search Query filtering
DummyElasticSearchModel.distinct_values("my_string.keyword", where: { _q: { "Hey" } })

# Distinct Values for single term with order
DummyElasticSearchModel.distinct_values("my_string.keyword", order: "_key")
DummyElasticSearchModel.distinct_values("my_string.keyword", order: { "_count" => "asc" })
DummyElasticSearchModel.distinct_values("my_string.keyword", order: ["_key", { "_count" => "asc" }])

# Distinct Values with partition
DummyElasticSearchModel.distinct_values("my_string.keyword", partition: 0, num_partitions: 2)
DummyElasticSearchModel.distinct_values("my_string.keyword", partition: 1, num_partitions: 2)

# Distinct Values with Additional Fields
DummyElasticSearchModel.distinct_values("my_int", additional_fields: ["my_string"])
DummyElasticSearchModel.distinct_values("my_int", additional_fields: ["my_int", "my_string"])
```

### Handling Model Name Changes
If you end up changing the name of a model, queries will not be able load elasticsearch data with the old name.  You can handle this
  by implementing a **model_class_from_name** method on your base search class.  For example:

```ruby
class DummyElasticSearchModel < ElasticsearchModels::Base
  class << self
    def model_class_from_name(class_name)
      if class_name == "OldReplacedModel"
        ShinyNewModel
      else
        super
      end
    end
  end
end
```

In order for searches on new models to include the old name, you need to implement **search_type** method on your new class.

```ruby
class ShinyNewModel < ElasticsearchModels::Base
  class << self
    def search_type
     ["OldReplacedModel", *super]
    end
  end
end
```
