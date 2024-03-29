# Elasticsearch Setup
## Test Setup

In order to run tests that involve Elasticsearch, you'll need to have Elasticsearch installed locally.

These steps use homebrew for installation. For other installation steps please see the [official Elasticsearch documentation](https://www.elastic.co/guide/index.html).

Check if Java8 is installed already

```shell
java -version
```

Example response with Java8 installed

```
java version "1.8.0_192"
Java(TM) SE Runtime Environment (build 1.8.0_192-b12)
Java HotSpot(TM) 64-Bit Server VM (build 25.192-b12, mixed mode)
```

Install Java8 if not installed already

```shell
brew tap adoptopenjdk/openjdk
brew install adoptopenjdk8
```

Now install Elasticsearch

```
brew install elasticsearch@6 # for 6
brew install elasticsearch # for 7
```

You should now be able to run tests involving Elasticsearch. Test setup should default to using port `9250` (so it does not conflict with the default local port `9200`).

### Running tests against your local elasticsearch

In order to quickly iterate over tests you can run them against your local Elasticsearch (so the tests don't need to spin up and down elasticsearch every time).

Set the local elasticsearch port in your bash environment and your tests will run against your local setup.

```shell
export ELASTICSEARCH_TEST_PORT=9200
```

## Local Setup
Run elasticsearch locally to use it with your local rails app.

```shell
elasticsearch
```

For a better experience use the supplied `docker-compose.yml` to run Elasticsearch along with Kibana locally.

```
docker-compose up # use Ctrl+C to exit
```

```
docker-compose up -d # detached mode
docker-compose down
```

Access Kibana locally at `localhost:5601`.

### Create index pattern
In order to view documents in Elasticsearch through Kibana, you need to create an index pattern.

On the Management page, click "Create index pattern".

When it asks for a regex to determine what indices to show you, you can enter `*` to show all or specify which index/indices.

If the indices for your pattern have a time field, select the appropriate time field filter or select "I don't want to use the Time Filter".
