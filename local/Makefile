SHELL := /bin/bash

# === BEGIN USER OPTIONS ===
# import env file
# You can change the default config with `make env="youfile.env" build`
env ?= .env
include $(env)
export $(shell sed 's/=.*//' $(env))

include ../vars.mk
include ../help.mk
include ../tls.mk
include init.mk
include setup.mk
include ../couchbase.mk
include ../rbac.mk
include ../functions.mk
include ../sso.mk
include ../vault.mk
include ../security.mk
include ../admin.mk
include ../bucket.mk
include ../settings.mk
include ../docs.mk
include ../observability.mk
include ../kmip.mk
include ../perf.mk
include ../build.mk
include ../xdcr.mk
include ../ldap.mk
include ../scan.mk
include ../jwt.mk
include ../index.mk

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

$(eval $(call defw,DOMAINS,couchbase.lan login.couchbase.lan node1.couchbase.lan node2.couchbase.lan node3.couchbase.lan node4.couchbase.lan))
MAIN_DOMAIN=$(shell echo $(DOMAINS) | awk '{print $$1}')

$(eval $(call defw,NODES,main east west misc))
MAIN_NODE=$(shell echo $(NODES) | awk '{print $$1}')

SERVICES?=data,index,query,fts
ADDITIONAL_SERVICES?=backup,eventing,analytics

# === END USER OPTIONS ===

### STACK

.PHONY: single/up
single/up: ##@single Start docker container
	$(DOCKER) run -it -d --rm \
		--env-file=./.env \
		--network $(ENV)_couchbase \
		--name="$(APP)_$(MAIN_NODE)" \
		$(EXPOSE_HOST) \
		--mount type=bind,source=$(MFILECWD)/.env,target=/opt/.env \
		--mount type=bind,source=$(MFILECWD)/../share,target=/opt/share \
 		--mount type=bind,source=$(MFILECWD)/../share/logs,target=/opt/couchbase/var/lib/couchbase/logs \
 		--mount type=bind,source=$(MFILECWD)/../share/data,target=/opt/couchbase/var \
		-w /opt/couchbase \
		-p 8091-8094:8091-8094  \
		-p 11210:11210  \
		-p 18091-18094:18091-18094  \
		-p 11207:11207 \
		--health-cmd "$(CURL) --fail $(API_ENDPOINT)/ui/index.html || exit 1" --health-interval=5s --health-timeout=3s --health-retries=10 --health-start-period=5s \
		$(DOCKER_IMAGE):$(VERSION)

.PHONY: single/up/novolume
single/up/novolume: ##@single Start docker container without volume
	$(DOCKER) run -it -d --rm \
		--env-file=./.env \
		--network $(ENV)_couchbase \
		--name="$(APP)_$(MAIN_NODE)" \
		$(EXPOSE_HOST) \
		--mount type=bind,source=$(MFILECWD)/../share/couchbase-server,target=/opt/couchbase/bin/couchbase-server \
		-w /opt/couchbase \
		-p 8091-8094:8091-8094  \
		-p 11210:11210  \
		-p 18091-18094:18091-18094  \
		-p 11207:11207 \
		--health-cmd "$(CURL) --fail $(API_ENDPOINT)/ui/index.html || exit 1" --health-interval=5s --health-timeout=3s --health-retries=10 --health-start-period=5s \
		$(DOCKER_IMAGE):$(VERSION)

.PHONY: single/down
single/down: ##@single Kill docker container
	$(DOCKER) stop "$(APP)_$(MAIN_NODE)"

.PHONY: single/delete
single/delete: ##@single Remove single cluster data
	rm -rf $(MFILECWD)/../share/logs/*.{log,bin,txt}
	rm -rf $(MFILECWD)/../share/data/lib

.PHONY: single/init
single/init: ##@single Init cluster
	@echo "Initializing cluster... with $(SERVICES) services"
	@(IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli cluster-init \
		--cluster couchbase://$$IP \
		--cluster-name $$CLUSTER_NAME \
  		--cluster-username $$COUCHBASE_USERNAME \
  		--cluster-password $$COUCHBASE_PASSWORD \
  		--services $(SERVICES) \
  		--cluster-ramsize $$COUCHBASE_RAM_SIZE \
  		--cluster-index-ramsize $$COUCHBASE_INDEX_RAM_SIZE \
  		--index-storage-setting default \
	)
	@(IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli node-init \
  		--username $$COUCHBASE_USERNAME \
  		--password $$COUCHBASE_PASSWORD \
		--cluster couchbase://$$IP \
		--node-init-hostname $$IP)

.PHONY: single/init/ip
setup/init/ip: ##@single print main node ip
	@(IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& echo $$IP)

.PHONY: cluster/setup/remote
cluster/setup/remote: ##@cluster Import sample data for xdcr node
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/pools/default/remoteClusters \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
  		--data-raw 'name=xdcr_cluster&hostname=couchbase_xdcr%3A8091&username=Administrator&password=password'

.PHONY: cluster/setup/replication
cluster/setup/replication: ##@cluster Create replication for xdcr node
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/controller/createReplication?just_validate=0 \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
  		--data-raw 'fromBucket=travel-sample&toCluster=xdcr_cluster&toBucket=travel-sample-replicated&priority=High&collectionsExplicitMapping=false&collectionsMigrationMode=false&filterBinary=false&filterExpiration=false&filterDeletion=false&filterBypassExpiry=false&compressionType=Auto&sourceNozzlePerNode=2&targetNozzlePerNode=2&checkpointInterval=600&workerBatchSize=500&docBatchSizeKb=2048&failureRestartInterval=10&optimisticReplicationThreshold=256&statsInterval=1000&networkUsageLimit=0&logLevel=Info&filterExpression=&replicationType=continuous&mobile=Off'

### CLUSTER

.PHONY: cluster/proxy
cluster/proxy: ##@cluster Start docker nginx proxy
	$(DOCKER) run -it -d --rm \
		--network $(ENV)_couchbase \
		--name="$(APP)_proxy" \
		--mount type=bind,source=$(MFILECWD)/../etc/proxy/nginx.conf,target=/etc/nginx/nginx.conf,readonly \
		--mount type=bind,source=$(MFILECWD)/../etc/proxy/cb.conf,target=/etc/nginx/conf.d/default.conf,readonly \
		--mount type=bind,source=$(MFILECWD)/../etc/tls/tls.pem,target=/etc/nginx/certs/nginx-selfsigned.crt \
		--mount type=bind,source=$(MFILECWD)/../etc/tls/tls.key,target=/etc/nginx/certs/nginx-selfsigned.key \
		-p 4091-4094:4091-4094  \
		$(PROXY_IMAGE)

cluster/proxy/stop: ##@cluster Stop docker nginx proxy
	$(DOCKER) stop "$(APP)_proxy"

.PHONY: cluster/up
cluster/up: ##@cluster Start docker containers cluster
	@port=8091; for n in $(NODES) ; do \
		low=$${port}; \
		high=$$((port+3)); \
		tlslow=$$((port+10000)); \
		tlshigh=$$((port+10003)); \
		$(DOCKER) run -it -d --rm --env-file=./.env --network $(ENV)_couchbase --name="$(APP)_$$n" $(EXPOSE_HOST) --mount type=bind,source=$(MFILECWD)/../share,target=/opt/share --mount type=bind,source=$(MFILECWD)/.env,target=/opt/.env -v $(ENV)_couchbase_$$n:/opt/couchbase/var -w /opt/couchbase -p $$low-$$high:8091-8094 -p $$tlslow-$$tlshigh:18091-18094 --health-cmd "$(CURL) --fail $(API_ENDPOINT)/ui/index.html || exit 1" --health-interval=5s --health-timeout=3s --health-retries=10 --health-start-period=5s $(DOCKER_IMAGE):$(VERSION); \
		((port=$$port+1000)) ; \
	done

.PHONY: cluster/up/ip
cluster/up/ip: ##@cluster Start docker containers cluster using separate ips
	@ip=1; for n in $(NODES) ; do \
		echo 192.168.99.$$ip:8091-8094:8091-8094; \
		$(DOCKER) run -it -d --rm --env-file=./.env --network $(ENV)_couchbase --name="$(APP)_$$n" $(EXPOSE_HOST) --mount type=bind,source=$(MFILECWD)/../share,target=/opt/share --mount type=bind,source=$(MFILECWD)/.env,target=/opt/.env -v $(ENV)_couchbase_$$n:/opt/couchbase/var -w /opt/couchbase -p 192.168.99.$$ip:8091-8094:8091-8094 -p 192.168.99.$$ip:18091-18094:18091-18094 --health-cmd "$(CURL) --fail $(API_ENDPOINT)/ui/index.html || exit 1" --health-interval=5s --health-timeout=3s --health-retries=10 --health-start-period=5s $(DOCKER_IMAGE):$(VERSION); \
		((ip=$$ip+1)) ; \
	done

.PHONY: cluster/init
cluster/init: ##@cluster Init cluster
	@(IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli cluster-init \
		--cluster couchbase://$$IP \
		--cluster-name $$CLUSTER_NAME \
  		--cluster-username $$COUCHBASE_USERNAME \
  		--cluster-password $$COUCHBASE_PASSWORD \
  		--services $(SERVICES) \
  		--cluster-ramsize $$COUCHBASE_RAM_SIZE \
  		--cluster-index-ramsize $$COUCHBASE_INDEX_RAM_SIZE \
  		--index-storage-setting default \
	)

.PHONY: cluster/worker/add
cluster/worker/add: ##@cluster Add workers to an existing cluster
	@(MAIN_IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_east` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-add \
		-c couchbase://$$MAIN_IP \
  		--username $$COUCHBASE_USERNAME \
  		--password $$COUCHBASE_PASSWORD \
		--server-add $$IP \
  		--services $(SERVICES) \
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
  		--services $(SERVICES) \
  		--index-storage-setting default \
		--server-add-username $$COUCHBASE_USERNAME \
  		--server-add-password $$COUCHBASE_PASSWORD \
	)

.PHONY: cluster/misc/add
cluster/misc/add: ##@cluster Add misc node to run search,analytics,eventing and backup
	@(MAIN_IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_misc` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-add \
		-c couchbase://$$MAIN_IP \
  		--username $$COUCHBASE_USERNAME \
  		--password $$COUCHBASE_PASSWORD \
		--server-add $$IP \
  		--services $(ADDITIONAL_SERVICES) \
  		--index-storage-setting default \
		--server-add-username $$COUCHBASE_USERNAME \
  		--server-add-password $$COUCHBASE_PASSWORD \
	)

.PHONY: cluster/rebalance
cluster/rebalance: ##@cluster Rebalance the cluster
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli rebalance \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \


.PHONY: cluster/down
cluster/down: ##@cluster Delete docker containers cluster
	@for n in $(NODES) ; do \
		$(DOCKER) stop "$(APP)_$$n"; \
	done

.PHONY: cluster/set-alt-address
cluster/set-alt-address: ##@cluster Set Alternate addresses on the nodes
	@port=8091; nr=1; for n in $(NODES) ; do \
		low=$${port}; \
		high=$$((port+3)); \
		tlslow=$$((port+10000)); \
		tlshigh=$$((port+10003)); \
		node=node$$nr".couchbase.lan"; \
		echo "$(APP)_$$n"; \
		$(DOCKER) exec -it "$(APP)_$$n" ./bin/couchbase-cli setting-alternate-address --set --node 127.0.0.1 --hostname $$node --ports mgmt=$$low --ports mgmtSSL=$$tlslow -c couchbase://127.0.0.1 --username $$COUCHBASE_USERNAME --password $$COUCHBASE_PASSWORD; \
		((port=$$port+1000)) ; \
		((nr++)); \
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

.PHONY: node/process/list
node/process/list: ##@node List running processes (deduped basenames)
	@$(DOCKER) top $(APP)_$(MAIN_NODE) -eo cmd \
	| sed '1d' \
	| awk '{exe=$$1; sub(".*/","",exe); print exe}' \
	| sort -u

.PHONY: node/process/list/full
node/process/list/full: ##@node List running processes (full command)
	@$(DOCKER) top $(APP)_$(MAIN_NODE) -eo pid,ppid,cmd \
	| sed '1d' \
	| awk '{pid=$$1;ppid=$$2; sub(/^[^ ]+[ \t]+[^ ]+[ \t]+/,""); exe=$$1; sub(".*/","",exe); \
	        printf "%s,%s,%s\n", pid, ppid, exe }'

.PHONY: node/process/list/native
node/process/list/native: ##@node List running processes (deduped basenames)
	@$(DOCKER) exec $(APP)_$(MAIN_NODE) ps -eo pid,ppid,user,stime,etime,stat,cmd --forest

.PHONY: node/process/list/native/full
node/process/list/native/full: | $(OUT) ## Export full process info
	@$(DOCKER) exec $(APP)_$(MAIN_NODE) sh -c \
	'ps -eo pid,ppid,uid,comm --no-headers' \
	| awk '{pid=$$1; ppid=$$2; uid=$$3; exe=$$4; ex[pid]=exe; par[pid]=ppid; u[pid]=uid} \
	       END{for (pid in ex){ pexe=ex[par[pid]]; if (pexe=="") pexe="-"; \
	                            printf "%s,%s,%s\n", ex[pid], pexe, u[pid] }}' \
	| sort -u
	
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