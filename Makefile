SHELL := /bin/bash

# ===SETUP
BLUE      := $(shell tput -Txterm setaf 4)
GREEN     := $(shell tput -Txterm setaf 2)
TURQUOISE := $(shell tput -Txterm setaf 6)
WHITE     := $(shell tput -Txterm setaf 7)
YELLOW    := $(shell tput -Txterm setaf 3)
GREY      := $(shell tput -Txterm setaf 1)
RESET     := $(shell tput -Txterm sgr0)

SMUL      := $(shell tput smul)
RMUL      := $(shell tput rmul)

ifeq ($(OS),Windows_NT)
    CCFLAGS += -D WIN32
    ifeq ($(PROCESSOR_ARCHITEW6432),AMD64)
        CCFLAGS += -D AMD64
    else
        ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
            CCFLAGS += -D AMD64
        endif
        ifeq ($(PROCESSOR_ARCHITECTURE),x86)
            CCFLAGS += -D IA32
        endif
    endif
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        CCFLAGS += -D LINUX
    endif
    ifeq ($(UNAME_S),Darwin)
        CCFLAGS += -D OSX
    endif
    UNAME_P := $(shell uname -p)
    ifeq ($(UNAME_P),x86_64)
        CCFLAGS += -D AMD64
    endif
    ifneq ($(filter %86,$(UNAME_P)),)
        CCFLAGS += -D IA32
    endif
    ifneq ($(filter arm%,$(UNAME_P)),)
        CCFLAGS += -D ARM
    endif
endif

# Variable wrapper
define defw
	custom_vars += $(1)
	$(1) ?= $(2)
	export $(1)
	shell_env += $(1)="$$($(1))"
endef

# Variable wrapper for hidden variables
define defw_h
	$(1) := $(2)
	shell_env += $(1)="$$($(1))"
endef

# Add the following 'help' target to your Makefile
# And add help text after each target name starting with '\#\#'
# A category can be added with @category
HELP_FUN = \
	%help; \
	use Data::Dumper; \
	while(<>) { \
		if (/^([_a-zA-Z0-9\-\/]+)\s*:.*\#\#(?:@([a-zA-Z0-9\-\/_\s]+))?\t(.*)$$/ \
			|| /^([_a-zA-Z0-9\-\/]+)\s*:.*\#\#(?:@([a-zA-Z0-9\-\/]+))?\s(.*)$$/) { \
			$$c = $$2; $$t = $$1; $$d = $$3; \
			push @{$$help{$$c}}, [$$t, $$d, $$ARGV] unless grep { grep { grep /^$$t$$/, $$_->[0] } @{$$help{$$_}} } keys %help; \
		} \
	}; \
	for (sort keys %help) { \
		printf("${WHITE}%24s:${RESET}\n\n", $$_); \
		for (@{$$help{$$_}}) { \
			printf("%s%25s${RESET}%s  %s${RESET}\n", \
				( $$_->[2] eq "Makefile" || $$_->[0] eq "help" ? "${YELLOW}" : "${GREY}"), \
				$$_->[0], \
				( $$_->[2] eq "Makefile" || $$_->[0] eq "help" ? "${GREEN}" : "${GREY}"), \
				$$_->[1] \
			); \
		} \
		print "\n"; \
	}


default: help

.PHONY: help
help:: ##@Other Show this help.
	@echo ""
	@printf "%30s " "${BLUE}VARIABLES"
	@echo "${RESET}"
	@echo ""
	@printf "${BLUE}%25s${RESET}${TURQUOISE}  ${SMUL}%s${RESET}\n" $(foreach v, $(custom_vars), $v $(if $($(v)),$($(v)), ''))
	@echo ""
	@echo ""
	@echo ""
	@printf "%30s " "${YELLOW}TARGETS"
	@echo "${RESET}"
	@echo ""
	@perl -e '$(HELP_FUN)' $(MAKEFILE_LIST)

# === BEGIN USER OPTIONS ===
# import env file
# You can change the default config with `make env="youfile.env" build`
env ?= .env
include $(env)
export $(shell sed 's/=.*//' $(env))

USERNAME=$(shell whoami)
UID=$(shell id -u ${USERNAME})
GID=$(shell id -g ${USERNAME})

MFILECWD = $(shell pwd)
ETC=$(MFILECWD)/etc
TLS=$(ETC)/tls

CRT_FILENAME=tls.pem
KEY_FILENAME=tls.key
DOCKER_BUILD_ARGS=
CURL_OPTS=

# Default params
API_ENDPOINT?=http://localhost:8091
PERMISSION?=cluster.admin.diag!read,cluster.admin.diag!write,cluster.admin.setup!write,cluster.admin.security!read,cluster.admin.security!write,cluster.admin.security.local!read,cluster.admin.security.local!write,cluster.admin.security.admin!write,cluster.admin.security.admin!read,cluster.admin.security.external!write,cluster.admin.security.external!read,cluster.admin.logs!read,cluster.admin.internal!all,cluster.admin.internal.stats!read,cluster.admin.internal.xdcr!read,cluster.admin.internal.xdcr!write,cluster.settings.indexes!write,cluster.admin.memcached!read,cluster.admin.memcached!write,cluster.admin.settings!read,cluster.admin.settings!write,cluster.logs!read,cluster.logs.fts!read,cluster.pools!read,cluster.pools!write,cluster.nodes!read,cluster.nodes!write,cluster.samples!read,cluster.settings!read,cluster.settings!write,cluster.settings.indexes!read,cluster.tasks!read,cluster.stats!read,cluster.stats.fts!read,cluster.server_groups!read,cluster.server_groups!write,cluster.indexes!read,cluster.indexes!write,cluster.xdcr.settings!read,cluster.xdcr.settings!write,cluster.xdcr.remote_clusters!read,cluster.xdcr.remote_clusters!write,cluster.xdcr.internal!read,cluster.xdcr.internal!write,cluster.analytics!select,cluster.analytics!manage,cluster.analytics!backup,cluster.fts!read,cluster.backup!all,cluster.eventing.functions!manage,cluster.settings.autocompaction!read,cluster.settings.autocompaction!write,cluster.settings!read,cluster.settings!write,cluster.settings.metrics!read,cluster.settings.metrics!write,cluster.settings.fts!read,cluster.settings.fts!write,cluster.n1ql.meta!read,cluster.n1ql.udf!manage,cluster.n1ql.udf_external!manage,cluster.n1ql.udf_external!execute,cluster.n1ql.udf!execute,cluster.n1ql.curl!execute,cluster.buckets!create,cluster.bucket[*]!create,cluster.bucket[*]!delete,cluster.bucket[*]!compact,cluster.bucket[*]!flush,cluster.bucket[*].settings!read,cluster.bucket[*].settings!write,cluster.bucket[*].recovery!write,cluster.bucket[*].recovery!read,cluster.bucket[*].password!read,cluster.bucket[*].data!read,cluster.bucket[*].data!write,cluster.bucket[*].data.docs!read,cluster.bucket[*].data.docs!write,cluster.bucket[*].data.docs!upsert,cluster.bucket[*].data.docs!delete,cluster.bucket[*].data.dcp!read,cluster.bucket[*].data.dcpstream!read,cluster.bucket[*].data.xattr!read,cluster.bucket[*].recovery!read,cluster.bucket[*].recovery!write,cluster.bucket[*].views!read,cluster.bucket[*].views!write,cluster.bucket[*].views!compact,cluster.bucket[*].xdcr!read,cluster.bucket[*].xdcr!write,cluster.bucket[*].xdcr!execute,cluster.bucket[*].n1ql.select!execute,cluster.bucket[*].n1ql.index!read,cluster.bucket[*].n1ql.index!write,cluster.bucket[*].n1ql.index!list,cluster.bucket[*].n1ql.udf!manage,cluster.bucket[*].n1ql.udf!execute,cluster.bucket[*].n1ql.meta!backup,cluster.bucket[*].analytics!manage,cluster.bucket[*].stats!read,cluster.bucket[*].fts!read,cluster.bucket[*].fts!write,cluster.bucket[*].data.dcpstream!read,cluster.bucket[*].collections!read,cluster.bucket[*].collections!write,cluster.scope[*:*].analytics!select,cluster.scope[*:*].data.dcpstream!read,cluster.scope[*:*].data.docs!read,cluster.scope[*:*].data.docs!write,cluster.scope[*:*].data.docs!upsert,cluster.scope[*:*].stats!read,cluster.scope[*:*].collections!read,cluster.scope[*:*].collections!write,cluster.scope[*:*].n1ql.index!read,cluster.scope[*:*].n1ql.index!write,cluster.scope[*:*].n1ql.index!list,cluster.scope[*:*].n1ql.select!execute,cluster.scope[*:*].n1ql.udf!manage,cluster.scope[*:*].n1ql.udf!execute,cluster.collection[*:*:*].analytics!select,cluster.collection[*:*:*].data.dcpstream!read,cluster.collection[*:*:*].data.docs!read,cluster.collection[*:*:*].data.docs!write,cluster.collection[*:*:*].data.docs!upsert,cluster.collection[*:*:*].data.docs!delete,cluster.collection[*:*:*].stats!read,cluster.collection[*:*:*].stats.fts!read,cluster.collection[*:*:*].fts!read,cluster.collection[*:*:*].fts!write,cluster.collection[*:*:*].collections!read,cluster.collection[*:*:*].collections!write,cluster.collection[*:*:*].n1ql.index!read,cluster.collection[*:*:*].n1ql.index!write,cluster.collection[*:*:*].n1ql.index!list,cluster.collection[*:*:*].n1ql.index!all,cluster.collection[*:*:*].n1ql.index!alter,cluster.collection[*:*:*].n1ql.index!build,cluster.collection[*:*:*].n1ql.index!create,cluster.collection[*:*:*].n1ql.index!drop,cluster.collection[*:*:*].n1ql.select!execute,cluster.collection[*:*:*].n1ql.update!execute,cluster.collection[*:*:*].n1ql.insert!execute,cluster.collection[*:*:*].n1ql.delete!execute,cluster.collection[*:*:*].n1ql.udf_external!manage,cluster.collection[*:*:*].n1ql.udf!manage,cluster.collection[*:*:*].eventing.function!manage,cluster.admin.stats_export!read,cluster.sgw.dev_ops!read,cluster.sgw.dev_ops!write,cluster.sgw.dev_ops!all,cluster.sgw.dev_ops!manage,cluster.admin.stats_export!read,cluster.admin.memcached.idle!write,cluster.settings.fts!manage,cluster.xdcr.developer!read,cluster.ui!read,cluster.sgw.dev_ops!all,cluster.eventing!all,cluster.analytics!all,cluster.buckets!all,cluster.bucket[*]!all,cluster.bucket[*]!read,cluster.bucket[*].n1ql.index!create,cluster.bucket[*].n1ql.index!build,cluster.bucket[*].settings.indexes!read,cluster.bucket[*].data!all,cluster.bucket[*].data.meta!read,cluster.bucket[*].data.meta!write,cluster.bucket[*].data.sxattr!read,cluster.bucket[*].data.sxattr!write,cluster.bucket[*].views!all,cluster.bucket[*].fts!manage,cluster.bucket[*].n1ql.index!all,cluster.bucket[*].n1ql!execute,cluster.collection[*:*:*].n1ql.udf!execute,cluster.collection[*:*:*].n1ql.udf_external!execute,cluster.collection[*:*:*].collections!all,cluster.collection[*:_system:*].data!read,cluster.collection[*:*:*].sgw!all,cluster.collection[*:*:*].sgw.replications!all,cluster.collection[*:*:*].sgw.auth!configure,cluster.collection[*:*:*].sgw.principal!read,cluster.collection[*:*:*].sgw.principal!write,cluster.collection[*:*:*].sgw.appdata!read,cluster.collection[*:*:*].sgw.appdata!write,cluster.collection[*:*:*].sgw.principal_appdata!read,cluster.collection[*:*:*].data.docs!insert,cluster.collection[*:*:*].data.docs!range_scan,cluster.collection[*:*:*].data.sxattr!read

BUCKET?=travel-sample
KEY?=airline_10

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

ROLES=admin ro_admin security_admin_local security_admin_external cluster_admin eventing_admin backup_admin replication_admin query_system_catalog query_external_access query_manage_global_functions query_execute_global_functions query_manage_global_external_functions query_execute_global_external_functions analytics_reader analytics_admin sync_gateway_dev_ops external_stats_reader
BUCKET_ROLES=bucket_admin scope_admin bucket_full_access views_admin views_reader data_reader data_writer data_dcp_reader data_backup data_monitoring fts_admin fts_searcher query_select query_update query_insert query_delete query_manage_index query_manage_functions query_execute_functions query_manage_external_functions query_execute_external_functions replication_target analytics_manager analytics_select mobile_sync_gateway sync_gateway_configurator sync_gateway_app sync_gateway_app_ro sync_gateway_replicator eventing_manage_functions

# === END USER OPTIONS ===

### DNS

.PHONY: dns/create
dns/insert: dns/remove ##@dns Create dns
	@echo "Creating HOST DNS entries for the project ..."
	@for v in $(DOMAINS) ; do \
		echo $$v; \
		sudo -- sh -c -e "echo '$(IP_ADDRESS)	$$v' >> /etc/hosts"; \
	done
	@echo "Completed..."

.PHONY: dns/remove
dns/remove: ##@dns Delete dns entries
	@echo "Removing HOST DNS entries ..."
	@for v in $(DOMAINS) ; do \
		echo $$v; \
		sudo -- sh -c "sed -i.bak \"/$(IP_ADDRESS)	$$v/d\" /etc/hosts && rm /etc/hosts.bak"; \
	done
	@echo "Completed..."

### CERTS

.PHONY: init
init: tls/create-cert tls/trust-cert network/create dns/insert## Running init tasks (create tls, dns and network)
	@echo "Init completed"

.PHONY: tls/create-cert
tls/create-cert:  ##@tls Create self sign certs for local machine
	@echo "Creating self signed certificate"
	docker run -it $(USER_DEF) \
		--mount "type=bind,src=$(TLS),dst=/home/mkcert" \
		--mount "type=bind,src=$(TLS),dst=/root/.local/share/mkcert" \
		istvano/mkcert:latest -install
	docker run -it $(USER_DEF) \
		--mount "type=bind,src=$(TLS),dst=/home/mkcert" \
		--mount "type=bind,src=$(TLS),dst=/root/.local/share/mkcert" \
		istvano/mkcert:latest -cert-file $(CRT_FILENAME) -key-file $(KEY_FILENAME) $(DOMAINS) localhost 127.0.0.1 ::1


.PHONY: delete-from-store
tls/delete-from-store: ##@tls delete self sign certs for local machine
	@[ -d ~/.pki/nssdb ] || mkdir -p ~/.pki/nssdb
	@(if [ -z $(shell certutil -d sql:$$HOME/.pki/nssdb -L | grep '$(MAIN_DOMAIN) cert authority' | head -n1 | awk '{print $$1;}') ]; \
	then \
		echo "not exists. skipping delete"; \
	else \
		certutil -d sql:$$HOME/.pki/nssdb -D -n '$(MAIN_DOMAIN) cert authority'; \
		echo "deleted"; \
	fi)
	@(if [ -z $(shell certutil -d sql:$$HOME/.pki/nssdb -L | grep '$(MAIN_DOMAIN)' | head -n1 | awk '{print $$1;}') ]; \
	then \
		echo "not exists. skipping delete"; \
	else \
		certutil -d sql:$$HOME/.pki/nssdb -D -n '$(MAIN_DOMAIN)'; \
		echo "deleted"; \
	fi)

.PHONY: tls/trust-cert
tls/trust-cert: tls/delete-from-store ##@tls Trust self signed cert by local browser
	@echo "Import self signed cert into user's truststore"
ifeq ($(UNAME_S),Darwin)
	sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $(TLS)/.local/share/mkcert/rootCA.pem
else
	@[ -d ~/.pki/nssdb ] || mkdir -p ~/.pki/nssdb
	@certutil -d sql:$$HOME/.pki/nssdb -A -n '$(MAIN_DOMAIN) cert authority' -i $(TLS)/.local/share/mkcert/rootCA.pem -t TCP,TCP,TCP
	@certutil -d sql:$$HOME/.pki/nssdb -A -n '$(MAIN_DOMAIN)' -i $(TLS)/tls.pem -t P,P,P
endif
	@echo "Import successful..."


# ### COMPOSE

# .PHONY: compose/up
# compose/up:  ##@Compose up
# 	$(COMPOSE) --project-name=$(PROJECT) up

# .PHONY: compose/ps
# compose/ps:  ##@Compose show processes
# 	$(COMPOSE) --project-name=$(PROJECT) ps

### DOCKER
.PHONY: network/create
network/create: ##@Docker create network
	$(DOCKER) network inspect $(ENV)_couchbase || $(DOCKER) network create $(ENV)_couchbase

.PHONY: network/delete
network/delete: ##@Docker delete network
	$(DOCKER) network inspect $(ENV)_couchbase && $(DOCKER) network rm $(ENV)_couchbase

.PHONY: volume/create
volume/create: ##@Docker create volume
	@for n in $(NODES) ; do \
		echo "Creating volume $(ENV)_couchbase_$$n"; \
		$(DOCKER) volume inspect $(ENV)_couchbase_$$n || $(DOCKER) volume create $(ENV)_couchbase_$$n; \
	done

.PHONY: volume/delete
volume/delete: ##@Docker delete volume
	@for n in $(NODES) ; do \
		echo "Deleting volume $(ENV)_couchbase_$$n"; \
		$(DOCKER) volume inspect $(ENV)_couchbase_$$n && $(DOCKER) volume rm $(ENV)_couchbase_$$n; \
	done

# .PHONY: build
# build:  ##@Docker build docker image
# 	$(DOCKER) build . -t $(APP) $(DOCKER_BUILD_ARGS)

# .PHONY: build-nc
# build-nc:  ##@Docker build docker image without using cache
# 	$(DOCKER) build . -t $(APP) $(DOCKER_BUILD_ARGS)

# .PHONY: tag
# tag: tag-latest tag-version ##@Docker Generate container tags for the `{version}` ans `latest` tags

# .PHONY: tag-latest
# tag-latest:
# 	@echo 'creating tag :latest'
# 	$(DOCKER) tag $(APP) $(DOCKER_REPO)/$(APP):latest

# .PHONY: tag-version
# tag-version:
# 	@echo 'creating tag $(VERSION)'
# 	$(DOCKER) tag $(APP) $(DOCKER_REPO)/$(APP):$(VERSION)

# .PHONY: release
# release: build-nc publish ##@Docker Build without cache and tag the docker image

.PHONY: publish
publish: push-tag push-latest

.PHONY: push-latest
push-latest:
	$(DOCKER) push $(DOCKER_REPO)/$(APP):latest

.PHONY: push-tag
push-tag:
	$(DOCKER) push $(DOCKER_REPO)/$(APP):$(VERSION)

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
	--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
  	--password $$COUCHBASE_ADMINISTRATOR_PASSWORD

.PHONY: cluster/server/list
cluster/server/list: ##@cluster List servers
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-list \
	-c couchbase://127.0.0.1 \
	--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
  	--password $$COUCHBASE_ADMINISTRATOR_PASSWORD

.PHONY: cluster/server/info
cluster/server/info: ##@cluster Show server info
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-info \
	-c couchbase://127.0.0.1 \
	--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
  	--password $$COUCHBASE_ADMINISTRATOR_PASSWORD

.PHONY: stat/bucket
stat/bucket: ##@stat Show DCB statistics
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/cbstats 127.0.0.1:11210 \
	dcp \
	-b $(BUCKET) \
	-u $$COUCHBASE_ADMINISTRATOR_USERNAME \
  	-p $$COUCHBASE_ADMINISTRATOR_PASSWORD

.PHONY: stat/all
stat/all: ##@stat Show vBucket stats
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/cbstats 127.0.0.1:11210 \
	all \
	-b $(BUCKET) \
	-u $$COUCHBASE_ADMINISTRATOR_USERNAME \
  	-p $$COUCHBASE_ADMINISTRATOR_PASSWORD

.PHONY: node/hash
node/hash: ##@node hash a given key
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/cbc hash  \
	$(KEY) \
	-U http://localhost/$(BUCKET) \
	-u $$COUCHBASE_ADMINISTRATOR_USERNAME \
	-P $$COUCHBASE_ADMINISTRATOR_PASSWORD

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
  		--cluster-username $$COUCHBASE_ADMINISTRATOR_USERNAME \
  		--cluster-password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
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
  		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
  		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
		--server-add $$IP \
  		--services data,index,query,fts \
  		--index-storage-setting default \
		--server-add-username $$COUCHBASE_ADMINISTRATOR_USERNAME \
  		--server-add-password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
	)
	@(MAIN_IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_west` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-add \
		-c couchbase://$$MAIN_IP \
  		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
  		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
		--server-add $$IP \
  		--services data,index,query,fts \
  		--index-storage-setting default \
		--server-add-username $$COUCHBASE_ADMINISTRATOR_USERNAME \
  		--server-add-password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
	)

.PHONY: setup/misc/add
setup/misc/add: ##@setup Add misc node to run search,analytics,eventing and backup
	@(MAIN_IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_misc` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-add \
		-c couchbase://$$MAIN_IP \
  		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
  		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
		--server-add $$IP \
  		--services backup,eventing,analytics \
  		--index-storage-setting default \
		--server-add-username $$COUCHBASE_ADMINISTRATOR_USERNAME \
  		--server-add-password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
	)

.PHONY: setup/cluster-rebalance
setup/rebalance: ##@setup Rebalance the cluster
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli rebalance \
		--cluster http://127.0.0.1 \
		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \

.PHONY: setup/create-user
setup/create-user: ##@setup Create User
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli user-manage \
		--cluster http://127.0.0.1 \
		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
		--set \
		--rbac-username $$COUCHBASE_RBAC_USERNAME \
		--rbac-password $$COUCHBASE_RBAC_PASSWORD \
		--roles mobile_sync_gateway[*] \
		--auth-domain local

.PHONY: setup/sample/import
setup/sample/import: ##@sample Import sample data from CB
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/sampleBuckets/install \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD \
		-d '["gamesim-sample","travel-sample", "beer-sample"]'

### PERFORMANCE

.PHONY: perf/bucket/create
perf/bucket/create: ##@perf Create bucket for performance tests
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli bucket-create -c localhost:8091 \
		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
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
		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
		--bucket performance \
		--wait

.PHONY: perf/document/create
perf/document/create: ##@perf delete the performance tests bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/cbworkloadgen -n localhost:8091 \
		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
		--bucket performance \
		-i 500000

### MOVIES

.PHONY: movies/create-bucket
movies/bucket/create: ##@movies Create bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli bucket-create -c localhost:8091 \
		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
		--bucket $$COUCHBASE_BUCKET \
		--bucket-ramsize $$COUCHBASE_BUCKET_RAMSIZE \
		--bucket-type couchbase \
		--wait 

.PHONY: movies/create-scope
movies/scope/create: ##@movies Create scope within the bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli collection-manage  -c localhost:8091 \
		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
		--bucket $$COUCHBASE_BUCKET \
		--create-scope sample

.PHONY: movies/create-collection
movies/collection/create: ##@movies Create collection within scope
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli collection-manage  -c localhost:8091 \
		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
		--bucket $$COUCHBASE_BUCKET \
		--create-collection sample.movies

.PHONY: movies/create-indexes
movies/index/create: ##@movies Create indexes
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v http://localhost:8093/query/service \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD \
		-d 'statement=CREATE PRIMARY INDEX `#primary` ON `playground`.`sample`.`movies`'

	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v http://localhost:8093/query/service \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD \
		-d 'statement=CREATE INDEX idx_movies_genres ON playground.sample.movies(DISTINCT ARRAY v FOR v IN genres END)'

.PHONY: movies/import
movies/import: ##@movies Import movies into the playground bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
		bash -c "curl https://raw.githubusercontent.com/prust/wikipedia-movie-data/master/movies.json  > /tmp/movies.json"
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	/opt/couchbase/bin/cbimport json -c couchbase://127.0.0.1 \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME -p $$COUCHBASE_ADMINISTRATOR_PASSWORD \
		--scope-collection-exp sample.movies \
		-b $$COUCHBASE_BUCKET -d file:///tmp/movies.json -f list -g \#UUID\#

.PHONY: movies/query
movies/query: ##@movies Run a query to filter out commedies
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v http://localhost:8093/query/service \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD \
		-d "statement=SELECT * FROM playground.sample.movies AS movies WHERE ANY v IN genres SATISFIES v = 'Comedy' END LIMIT 10"
### Rest

.PHONY: rest/rbac/whoami
rest/rbac/whoami: ##@rest Get whoami
	@$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/whoami \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD | jq

.PHONY: rest/rbac/roles
rest/rbac/roles: ##@rest Get the roles
	@$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/roles \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD | jq	

.PHONY: rest/rbac/users
rest/rbac/users: ##@rest Get the users
	@$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/users \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD | jq	

.PHONY: rest/rbac/groups
rest/rbac/groups: ##@rest Get the groups
	@$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/groups \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD | jq

.PHONY: rest/rbac/create-user-per-roles
rest/rbac/create-user-per-roles: ##@rest Create a user for every role		
	@for v in $(ROLES) ; do \
		echo "Creating user: $$v"; \
		ROLE_STR="roles=$$v&password=password"; \
		$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
		$(CURL) $(CURL_OPTS) -X PUT $(API_ENDPOINT)/settings/rbac/users/local/$$v \
			-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD \
			-d $$ROLE_STR; \
	done
	@for v in $(BUCKET_ROLES) ; do \
		echo "Creating user: $$v"; \
		ROLE_STR="roles=$$v[*]&password=password"; \
		$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
		$(CURL) $(CURL_OPTS) -X PUT $(API_ENDPOINT)/settings/rbac/users/local/$$v \
			-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD \
			-d $$ROLE_STR; \
	done
	@echo "Completed..."

.PHONY: rest/rbac/delete-user-per-roles
rest/rbac/delete-user-per-roles: ##@rest Create a user for every role
	@for v in $(ROLES) ; do \
		echo "Deleting user: $$v"; \
		ROLE_STR="roles=$$v&password=password"; \
		$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
		$(CURL) $(CURL_OPTS) -X DELETE $(API_ENDPOINT)/settings/rbac/users/local/$$v \
			-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD; \
	done
	@for v in $(BUCKET_ROLES) ; do \
		echo "Deleting user: $$v"; \
		ROLE_STR="roles=$$v&password=password"; \
		$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
		$(CURL) $(CURL_OPTS) -X DELETE $(API_ENDPOINT)/settings/rbac/users/local/$$v \
			-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD; \
	done
	@echo "Completed..."

.PHONY: rest/rbac/check-perms-all
rest/rbac/check-perms-all: ##@rest Get user permissions for all users
	@for v in $(ROLES) ; do \
		echo "User: $$v"; \
		$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
		$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/checkPermissions \
		-u $$v:$$COUCHBASE_ADMINISTRATOR_PASSWORD \
		-d '$(PERMISSION)' | jq | grep -E '{|}|true' ;\
	done
	@for v in $(BUCKET_ROLES) ; do \
		echo "User: $$v"; \
		$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
		$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/checkPermissions \
		-u $$v:$$COUCHBASE_ADMINISTRATOR_PASSWORD \
		-d '$(PERMISSION)' | jq | grep -E '{|}|true' ;\
	done


.PHONY: rest/rbac/check-perms
rest/rbac/check-perms: ##@rest Get the users
	@$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/checkPermissions \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD \
		-d '$(PERMISSION)' | jq

.PHONY: rest/audit/config
rest/audit/config: ##@rest Get config
	@$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/audit \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD | jq

.PHONY: rest/audit/enable
rest/audit/enable: ##@rest Enable audit
	@$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -X POST $(API_ENDPOINT)/settings/audit \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD \
		-d 'auditdEnabled=true' \
		-d 'disabled=8243,8255,8257,32770,32771,32772,32780,32783,32784,32785,32786,40963' \
		-d 'rotateSize=524288000' \
		-d 'rotateInterval=7200' \
		-d 'logPath=/opt/couchbase/var/lib/couchbase/logs' | jq

.PHONY: rest/audit/listauditevents
rest/audit/listauditevents: ##@rest List auditable events
	@$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/audit/descriptors \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD | jq

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