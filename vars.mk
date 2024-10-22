
CRT_FILENAME?=tls.pem
KEY_FILENAME?=tls.key

USERNAME=$(shell whoami)
UID=$(shell id -u ${USERNAME})
GID=$(shell id -g ${USERNAME})

MFILECWD = $(shell pwd)
ETC=$(MFILECWD)/../etc
TLS=$(ETC)/tls

DOCKER_BUILD_ARGS?=
CURL_OPTS?=

DB_USER?=$(COUCHBASE_USERNAME)