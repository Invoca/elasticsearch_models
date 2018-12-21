# ElasticsearchModels
Model representation for Elasticsearch documents

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
See [SETUP.md]("https://github.com/Invoca/elasticsearch_models/SETUP.md") for steps on installing and working with Elasticsearch locally.

## Usage
All classes that you want to store as documents should inherit from `ElasticsearchModels::Base` (which inherits from `ElasticsearchModels::Aggregate`). All classes (including nested classes) should inherit from `ElasticsearchModels::Aggregate`.

-
**TODO: Add full details**
