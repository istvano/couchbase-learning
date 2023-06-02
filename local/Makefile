SHELL := /bin/bash

# === BEGIN USER OPTIONS ===
# import env file
# You can change the default config with `make env="youfile.env" build`
env ?= .env
include $(env)
export $(shell sed 's/=.*//' $(env))

include ../help.mk
include setup.mk
include ../couchbase.mk
include ../rbac.mk
include ../sso.mk
include ../vault.mk

USERNAME=$(shell whoami)
UID=$(shell id -u ${USERNAME})
GID=$(shell id -g ${USERNAME})

MFILECWD = $(shell pwd)
ETC=$(MFILECWD)/../etc
TLS=$(ETC)/tls

DOCKER_BUILD_ARGS?=
CURL_OPTS?=

DB_USER?=$(COUCHBASE_USERNAME)

#space separated string array ->
$(eval $(call defw,IP_ADDRESS,$(IP_ADDRESS)))
$(eval $(call defw,NAMESPACES,couchbase))
$(eval $(call defw,DEFAULT_NAMESPACE,$(shell echo $(NAMESPACES) | awk '{print $$1}')))
$(eval $(call defw,ENV,$(ENV)))
$(eval $(call defw,CLUSTER_NAME,$(shell basename $(MFILECWD))))
$(eval $(call defw,DOCKER,docker))
$(eval $(call defw,CURL,curl))
$(eval $(call defw,COMPOSE,docker-compose))
$(eval $(call defw,UNAME,$(UNAME_S)-$(UNAME_P)))

ifeq ($(UNAME_S),Darwin)
	IP_ADDRESS=$(shell ipconfig getifaddr en0 | awk '{print $$1}')
	USER_DEF=
	PLATFORM=--platform linux/arm64
	OPEN=open
else
	IP_ADDRESS=$(shell hostname -I | awk '{print $$1}')
	OPEN=xdg-open
	USER_DEF=--user $(UID):$(UID)
	PLATFORM=--platform linux/amd64
endif

ifeq ($(IP_ADDRESS),)
	IP_ADDRESS=127.0.0.1
endif

$(eval $(call defw,DOMAINS,couchbase.lan *.couchbase.lan))
MAIN_DOMAIN=$(shell echo $(DOMAINS) | awk '{print $$1}')

$(eval $(call defw,NODES,main east west misc))
MAIN_NODE=$(shell echo $(NODES) | awk '{print $$1}')


# === END USER OPTIONS ===


### STACK

.PHONY: single/up
single/up: ##@single Start docker container
	$(DOCKER) run -it -d --rm \
		--env-file=./.env \
		--network $(ENV)_couchbase \
		--name="$(APP)_$(MAIN_NODE)" \
		--mount type=bind,source=$(MFILECWD)/.env,target=/opt/.env \
		-v $(ENV)_couchbase_$(MAIN_NODE):/opt/couchbase/var \
		-w /opt/couchbase \
		-p 8091-8094:8091-8094  \
		-p 11210:11210  \
		-p 18091-18094:18091-18094  \
		--health-cmd "$(CURL) --fail $(API_ENDPOINT)/ui/index.html || exit 1" --health-interval=5s --health-timeout=3s --health-retries=10 --health-start-period=5s \
		$(DOCKER_IMAGE):$(VERSION)

.PHONY: single/down
single/down: ##@single Kill docker container
	$(DOCKER) stop "$(APP)_$(MAIN_NODE)"

### CLUSTER

.PHONY: cluster/up
cluster/up: ##@cluster Start docker containers cluster
	@c=8; for n in $(NODES) ; do \
		low=$$c"091"; \
		high=$$c"094"; \
		$(DOCKER) run -it -d --rm --env-file=./.env --network $(ENV)_couchbase --name="$(APP)_$$n" --mount type=bind,source=$(MFILECWD)/.env,target=/opt/.env -v $(ENV)_couchbase_$$n:/opt/couchbase/var -w /opt/couchbase -p $$low-$$high:8091-8094  --health-cmd "$(CURL) --fail $(API_ENDPOINT)/ui/index.html || exit 1" --health-interval=5s --health-timeout=3s --health-retries=10 --health-start-period=5s $(DOCKER_IMAGE):$(VERSION); \
		((c=$$c+1)) ; \
	done

.PHONY: cluster/down
cluster/down: ##@cluster Delete docker containers cluster
	@for n in $(NODES) ; do \
		$(DOCKER) stop "$(APP)_$$n"; \
	done

.PHONY: cluster/bucket/list
cluster/bucket/list: ##@cluster List buckets
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli bucket-list \
	-c couchbase://127.0.0.1 \
	--username $$COUCHBASE_USERNAME \
  	--password $$COUCHBASE_PASSWORD

.PHONY: cluster/server/list
cluster/server/list: ##@cluster List servers
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-list \
	-c couchbase://127.0.0.1 \
	--username $$COUCHBASE_USERNAME \
  	--password $$COUCHBASE_PASSWORD

.PHONY: cluster/server/info
cluster/server/info: ##@cluster Show server info
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-info \
	-c couchbase://127.0.0.1 \
	--username $$COUCHBASE_USERNAME \
  	--password $$COUCHBASE_PASSWORD

.PHONY: stat/bucket
stat/bucket: ##@stat Show DCB statistics
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/cbstats 127.0.0.1:11210 \
	dcp \
	-b $(BUCKET) \
	-u $$COUCHBASE_USERNAME \
  	-p $$COUCHBASE_PASSWORD

.PHONY: stat/all
stat/all: ##@stat Show vBucket stats
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/cbstats 127.0.0.1:11210 \
	all \
	-b $(BUCKET) \
	-u $$COUCHBASE_USERNAME \
  	-p $$COUCHBASE_PASSWORD

.PHONY: node/hash
node/hash: ##@node hash a given key
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/cbc hash  \
	$(KEY) \
	-U http://localhost/$(BUCKET) \
	-u $$COUCHBASE_USERNAME \
	-P $$COUCHBASE_PASSWORD

.PHONY: node/ssh
node/ssh: ##@node SSH docker container
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) bash 

.PHONY: node/log
node/log: ##@node LOG tail
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) tail /opt/couchbase/var/lib/couchbase/logs/info.log

.PHONY: node/console
node/console: ##@node Open web console
	$(OPEN) $(API_ENDPOINT)

### SETUP

.PHONY: setup/init
setup/init: ##@setup Init cluster
	@(IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli cluster-init \
		-c couchbase://$$IP \
		--cluster-name $$CLUSTER_NAME \
  		--cluster-username $$COUCHBASE_USERNAME \
  		--cluster-password $$COUCHBASE_PASSWORD \
  		--services data,index,query,fts \
  		--cluster-ramsize $$COUCHBASE_RAM_SIZE \
  		--cluster-index-ramsize $$COUCHBASE_INDEX_RAM_SIZE \
  		--index-storage-setting default \
		--node-to-node-encryption off \
	)

.PHONY: setup/worker/add
setup/worker/add: ##@setup Add workers to an existing cluster
	@(MAIN_IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_east` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-add \
		-c couchbase://$$MAIN_IP \
  		--username $$COUCHBASE_USERNAME \
  		--password $$COUCHBASE_PASSWORD \
		--server-add $$IP \
  		--services data,index,query,fts \
  		--index-storage-setting default \
		--server-add-username $$COUCHBASE_USERNAME \
  		--server-add-password $$COUCHBASE_PASSWORD \
	)
	@(MAIN_IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_west` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-add \
		-c couchbase://$$MAIN_IP \
  		--username $$COUCHBASE_USERNAME \
  		--password $$COUCHBASE_PASSWORD \
		--server-add $$IP \
  		--services data,index,query,fts \
  		--index-storage-setting default \
		--server-add-username $$COUCHBASE_USERNAME \
  		--server-add-password $$COUCHBASE_PASSWORD \
	)

.PHONY: setup/misc/add
setup/misc/add: ##@setup Add misc node to run search,analytics,eventing and backup
	@(MAIN_IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_misc` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-add \
		-c couchbase://$$MAIN_IP \
  		--username $$COUCHBASE_USERNAME \
  		--password $$COUCHBASE_PASSWORD \
		--server-add $$IP \
  		--services backup,eventing,analytics \
  		--index-storage-setting default \
		--server-add-username $$COUCHBASE_USERNAME \
  		--server-add-password $$COUCHBASE_PASSWORD \
	)

.PHONY: setup/cluster-rebalance
setup/rebalance: ##@setup Rebalance the cluster
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli rebalance \
		--cluster http://127.0.0.1 \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \

.PHONY: setup/create-user
setup/create-user: ##@setup Create User
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli user-manage \
		--cluster http://127.0.0.1 \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--set \
		--rbac-username $$COUCHBASE_RBAC_USERNAME \
		--rbac-password $$COUCHBASE_RBAC_PASSWORD \
		--roles mobile_sync_gateway[*] \
		--auth-domain local

.PHONY: setup/sample/import
setup/sample/import: ##@sample Import sample data from CB
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/sampleBuckets/install \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d '["gamesim-sample","travel-sample", "beer-sample"]'

### PERFORMANCE

.PHONY: perf/bucket/create
perf/bucket/create: ##@perf Create bucket for performance tests
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli bucket-create -c localhost:8091 \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--bucket performance \
		--bucket-ramsize 100 \
		--bucket-replica 0 \
  		--enable-flush 1 \
  		--enable-index-replica 0 \
		--bucket-type couchbase \
		--wait 

.PHONY: perf/bucket/delete
perf/bucket/delete: ##@perf delete the performance tests bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli delete-create -c localhost:8091 \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--bucket performance \
		--wait

.PHONY: perf/document/create
perf/document/create: ##@perf delete the performance tests bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/cbworkloadgen -n localhost:8091 \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--bucket performance \
		-i 500000

### MOVIES

.PHONY: movies/create-bucket
movies/bucket/create: ##@movies Create bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli bucket-create -c localhost:8091 \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--bucket $$COUCHBASE_BUCKET \
		--bucket-ramsize $$COUCHBASE_BUCKET_RAMSIZE \
		--bucket-type couchbase \
		--wait 

.PHONY: movies/create-scope
movies/scope/create: ##@movies Create scope within the bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli collection-manage  -c localhost:8091 \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--bucket $$COUCHBASE_BUCKET \
		--create-scope sample

.PHONY: movies/create-collection
movies/collection/create: ##@movies Create collection within scope
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli collection-manage  -c localhost:8091 \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--bucket $$COUCHBASE_BUCKET \
		--create-collection sample.movies

.PHONY: movies/create-indexes
movies/index/create: ##@movies Create indexes
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v http://localhost:8093/query/service \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d 'statement=CREATE PRIMARY INDEX `#primary` ON `playground`.`sample`.`movies`'

	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v http://localhost:8093/query/service \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d 'statement=CREATE INDEX idx_movies_genres ON playground.sample.movies(DISTINCT ARRAY v FOR v IN genres END)'

.PHONY: movies/import
movies/import: ##@movies Import movies into the playground bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
		bash -c "curl https://raw.githubusercontent.com/prust/wikipedia-movie-data/master/movies.json  > /tmp/movies.json"
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	/opt/couchbase/bin/cbimport json -c couchbase://127.0.0.1 \
		-u $$COUCHBASE_USERNAME -p $$COUCHBASE_PASSWORD \
		--scope-collection-exp sample.movies \
		-b $$COUCHBASE_BUCKET -d file:///tmp/movies.json -f list -g \#UUID\#

.PHONY: movies/query
movies/query: ##@movies Run a query to filter out commedies
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v http://localhost:8093/query/service \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d "statement=SELECT * FROM playground.sample.movies AS movies WHERE ANY v IN genres SATISFIES v = 'Comedy' END LIMIT 10"


.PHONY: rest/audit/config
rest/audit/config: ##@rest Get config
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/audit \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq

.PHONY: rest/audit/enable
rest/audit/enable: ##@rest Enable audit
	$(CURL) $(CURL_OPTS) -X POST $(API_ENDPOINT)/settings/audit \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d 'auditdEnabled=true' \
		-d 'disabled=8243,8255,8257,32770,32771,32772,32780,32783,32784,32785,32786,40963' \
		-d 'rotateSize=524288000' \
		-d 'rotateInterval=7200' \
		-d 'logPath=/opt/couchbase/var/lib/couchbase/logs' | jq

.PHONY: rest/audit/listauditevents
rest/audit/listauditevents: ##@rest List auditable events
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/audit/descriptors \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq

### MISC

.PHONY: synctime
synctime: ##@misc Sync VM time
	@sudo sudo timedatectl set-ntp off
	@sudo timedatectl set-ntp on
	@date

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