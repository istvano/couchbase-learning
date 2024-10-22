SHELL := /bin/bash

# === BEGIN USER OPTIONS ===
# import env file
# You can change the default config with `make env="youfile.env" build`
env ?= .env
include $(env)
export $(shell sed 's/=.*//' $(env))

include ../vars.mk
include ../help.mk
include ../couchbase.mk
include ../rbac.mk
include ../tls.mk
include ../security.mk
include ../backup.mk
include api.mk

MFILECWD = $(shell pwd)
ETC=$(MFILECWD)/../etc
TLS=$(ETC)/tls

CURL_OPTS?=-k -v --insecure

$(eval $(call defw,ENV,$(ENV)))
$(eval $(call defw,DOCKER,docker))
$(eval $(call defw,CURL,curl))
$(eval $(call defw,COMPOSE,docker-compose))
$(eval $(call defw,UNAME,$(UNAME_S)-$(UNAME_P)))

.PHONY: rest/buckets
rest/buckets: ##@rest List buckets
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/buckets \
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