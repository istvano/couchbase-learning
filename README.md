# couchbase-learning

## Initialize

* clone the repository
* for local development `cd local`
* for Capella `cd provisioned` please note: Capella has limitations and not all functions will work

### Variables

If you are planning to run local nodes with Docker, edit the `.env` file in the local folder

Select the docker image source and version

```bash
DOCKER_IMAGE?=ghcr.io/cb-vanilla/server
VERSION?=8.0.0
```

By default this will pull from private github repository, if you use the open releases use

```bash
DOCKER_IMAGE?=couchbase
VERSION?=enterprise-7.6.7
```

By default, this image uses podman to bring up containers, you need to edit the `.env` file to use docker instead

```
# Docker host
INTERNAL_ENDPOINT=https://docker.for.mac.host.internal
DOCKER=docker
EXPOSE_HOST=--add-host login.couchbase.lan:host-gateway

# Podman host
# INTERNAL_ENDPOINT=https://host.containers.internal
# INTERNAL_DOMAIN=host.containers.internal
# DOCKER=podman
# EXPOSE_HOST=
```


### Common steps

* `make network/create` to create a docker network
* `make volume/create` to create volumes for the nodes

Optionally you can create a dns for the local cluster, this is not necessary

* `make dns/insert` to create dns for the nodes, this is needed if your work / test involves using dns related functionalty

### Single node

* `make single/up` this will bring up a single node cluster
* `make cluster/init` this will create a user called `Administrator` with the credential `password`

This will start the main node and also initialize a single node cluster with the following services: **data,index,query**

### Multi node

* `make cluster/up` will create 4 docker containers:

1. a main node
2. east and west nodes 
3. also a misc node

* `make setup/cluster-init` will initialize the main node with **data, index, query** services

* `make setup/cluster-add-workers` will add east and west as worker nodes all running **data, index, query** services

* `make setup/cluster-add-misc-node` will add **search, analitics, eventing and backup** services using a single docker container

* `setup/cluster-rebalance`

## Initialize

* `make setup/create-user` will create a different admin user

## Sample data

### Couchbase

* `make setup/sample/import` will load the couchbase sample dataset

### Custom movies dataset

* `make movies/bucket/create` will create bucket named playground

* `make movies/scope/create` will create scope within the playground bucket called sample

* `make movies/collection/create`  will create scope within the playground bucket called movies

* `make movies/create-indexes`  will create a sample index 

```sql
CREATE PRIMARY INDEX `#primary` ON `playground`.`sample`.`movies`'
```

* `make movies/import`  Import movies into the playground bucket

will import https://raw.githubusercontent.com/prust/wikipedia-movie-data/master/movies.json dataset into the movies collection

* `make movies/query`  Run a query to filter out commedies

will run a sample query

```sql
SELECT * FROM playground.sample.movies AS movies WHERE ANY v IN genres SATISFIES v = 'Comedy' END LIMIT 10
```

to see if the sample data is correct

### KMIP with pykmip

* you go to the local folder `cd local`
* create the network `make network/create`
* create certs for kmip `make kmip/tls/create`
* build kmip container `make kmip/pykmip/build`
* run pykmip `make kmip/pykmip/run`
* check if kmip works `make kmip/pykmip/test`


### KMIP with cosmian

* you go to the local folder `cd local`
* create the network `make network/create`
* create certs for kmip `make kmip/tls/create`
* run cosmian `make kmip/cosmian/run`
* check kmip server `make kmip/cosmian/ver`
* create a symetric key `kmip/cosmian/key/create`
* encrypt a file `kmip/cosmian/key/encrypt`
* decrypt a file `kmip/cosmian/key/decrypt`

### Mutual TLS authentication

* Assuming you are in the local folder, or go to the local folder `cd local`
* you need to create a CA that will be used to sign the client certificate `make tls/ca/create`
* now you can create the client private key and certificate `make tls/client/create`
* you need to copy the CA created earlier to the Couchbase index/CA make `make tls/ca/copy`
* use the couchbase CLI to reload the certs `make tls/ca/load`
* create a user with the same name as the one in the certificate `make tls/client/create-user`
* load the settings and enable client cert authentication `make settings/clientcert/load`
* call an endpoint with the mtls settings see `make tls/client/test`

You should check out the **client.ext** file in the tls folder as it has the username 
