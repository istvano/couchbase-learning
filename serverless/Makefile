SHELL := /bin/bash

# === BEGIN USER OPTIONS ===
# import env file
# You can change the default config with `make env="youfile.env" build`
env ?= .env
include $(env)
export $(shell sed 's/=.*//' $(env))

include ../help.mk
include ../couchbase.mk
include ../rbac.mk

CURL_OPTS?=-k

$(eval $(call defw,ENV,$(ENV)))
$(eval $(call defw,DOCKER,docker))
$(eval $(call defw,CURL,curl))
$(eval $(call defw,COMPOSE,docker-compose))
$(eval $(call defw,UNAME,$(UNAME_S)-$(UNAME_P)))

.PHONY: rest/ping
rest/buckets: ##@rest Ping
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/ping \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq

.PHONY: rest/samples
rest/samples: ##@rest Ping
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/v1/scopes/samples/collections/airline/docs \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq

.PHONY: rest/databases
rest/databases: ##@rest Get databases
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/v2/databases \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq

# === END USER OPTIONS ===

.PHONY: versions
versions: ##@misc Print the "imporant" tools versions out for easier debugging.
	@echo "=== BEGIN Version Info ==="
	@echo "Project name: ${PROJECT}"
	@echo "version: ${VERSION}"
	@echo "Repo state: $$(git rev-parse --verify HEAD) (dirty? $$(if git diff --quiet; then echo 'NO'; else echo 'YES'; fi))"
	@echo "make: $$(command -v make)"
	@echo "kubectl: $$(command -v kubectl)"
	@echo "grep: $$(command -v grep)"
	@echo "cut: $$(command -v cut)"
	@echo "rsync: $$(command -v rsync)"
	@echo "openssl: $$(command -v openssl)"
	@echo "/dev/urandom: $$(if test -c /dev/urandom; then echo OK; else echo 404; fi)"
	@echo "=== END Version Info ==="

.EXPORT_ALL_VARIABLES: