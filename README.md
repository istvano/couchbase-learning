# couchbase-learning

## Initialize

### Common steps

* make tls/create-cert
* make dns/insert
* make network/create

### Single node

* make up
* make setup/cluster-init

This will start the main node and also initialize a single node cluster with the following services: **data,index,query**

### Multi node

* make cluster/up

will create 4 docker containers:

1. a main node
2. east and west nodes 
3. also a misc node

* make setup/cluster-init

will initialize the main node with **data, index, query** services

* make setup/cluster-add-workers

will add east and west as worker nodes all running **data, index, query** services

* make setup/cluster-add-misc-node

will add **search, analitics, eventing and backup** services using a single docker container

* setup/cluster-rebalance

## Initialize

* make setup/create-user

## Sample data

### Couchbase

* make sample/import-cb-sample

will load the couchbase sample dataset

### Custom movies dataset

* movies/create-bucket  

will create bucket named playground

* movies/create-scope  

will create scope within the playground bucket called sample

* movies/create-collection  Create collection within scope

will create scope within the playground bucket called movies

* movies/create-indexes  Create indexes

will create a sample index 

```sql
CREATE PRIMARY INDEX `#primary` ON `playground`.`sample`.`movies`'
```

* movies/import  Import movies into the playground bucket

will import https://raw.githubusercontent.com/prust/wikipedia-movie-data/master/movies.json dataset into the movies collection

* movies/query  Run a query to filter out commedies

will run a sample query

```sql
SELECT * FROM playground.sample.movies AS movies WHERE ANY v IN genres SATISFIES v = 'Comedy' END LIMIT 10
```

to see if the sample data is correct

### KMIP

* you go to the local folder `cd local`
* create the network `make network/create`
* create certs for kmip `make kmip/tls/create`
* start kmip container `make kmip/up`
* check if kmip works `make kmip/ver`