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

#space separated string array ->
$(eval $(call defw,IP_ADDRESS,$(IP_ADDRESS)))
$(eval $(call defw,NAMESPACES,couchbase))
$(eval $(call defw,DEFAULT_NAMESPACE,$(shell echo $(NAMESPACES) | awk '{print $$1}')))
$(eval $(call defw,ENV,$(ENV)))
$(eval $(call defw,CLUSTER_NAME,$(shell basename $(MFILECWD))))
$(eval $(call defw,DOCKER,docker))
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
tls/delete-from-store:
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

### DEVELOPMENT

.PHONY: up
up: ##@dev Start docker container
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
		$(DOCKER_IMAGE):$(VERSION)

.PHONY: down
down: ##@dev Kill docker container
	$(DOCKER) stop "$(APP)_$(MAIN_NODE)"

.PHONY: cluster/up
cluster/up: ##@dev Start docker containers cluster
	@c=8; for n in $(NODES) ; do \
		low=$$c"091"; \
		high=$$c"094"; \
		$(DOCKER) run -it -d --rm --env-file=./.env --network $(ENV)_couchbase --name="$(APP)_$$n" --mount type=bind,source=$(MFILECWD)/.env,target=/opt/.env -v $(ENV)_couchbase_$$n:/opt/couchbase/var -w /opt/couchbase -p $$low-$$high:8091-8094  $(DOCKER_IMAGE):$(VERSION); \
		((c=$$c+1)) ; \
	done

.PHONY: cluster/down
cluster/down: ##@dev Delete docker containers cluster
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

.PHONY: ssh
ssh: ##@dev SSH docker container
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) bash 

.PHONY: log/tail
log/tail: ##@log LOG tail
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) tail /opt/couchbase/var/lib/couchbase/logs/info.log

.PHONY: console
console: ##@dev Open web console
	$(OPEN) http://localhost:8091

### SETUP

.PHONY: setup/cluster-init
setup/cluster-init: ##@setup Init cluster
	@(IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli cluster-init \
		-c couchbase://$$IP \
		--cluster-name $$CLUSTER_NAME \
  		--cluster-username $$COUCHBASE_ADMINISTRATOR_USERNAME \
  		--cluster-password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
  		--services data,index,query \
  		--cluster-ramsize $$COUCHBASE_RAM_SIZE \
  		--cluster-index-ramsize $$COUCHBASE_INDEX_RAM_SIZE \
  		--index-storage-setting default \
		--node-to-node-encryption off \
	)

.PHONY: setup/cluster-add-workers
setup/cluster-add-workers: ##@setup Add workers to an existing cluster
	@(MAIN_IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_east` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-add \
		-c couchbase://$$MAIN_IP \
  		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
  		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
		--server-add $$IP \
  		--services data,index,query \
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
  		--services data,index,query \
  		--index-storage-setting default \
		--server-add-username $$COUCHBASE_ADMINISTRATOR_USERNAME \
  		--server-add-password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
	)

.PHONY: setup/cluster-add-misc-node
setup/cluster-add-misc-node: ##@setup Add misc node to run search,analytics,eventing and backup
	@(MAIN_IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_misc` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-add \
		-c couchbase://$$MAIN_IP \
  		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
  		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
		--server-add $$IP \
  		--services fts,backup,eventing,analytics \
  		--index-storage-setting default \
		--server-add-username $$COUCHBASE_ADMINISTRATOR_USERNAME \
  		--server-add-password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
	)

.PHONY: setup/cluster-rebalance
setup/cluster-rebalance: ##@setup Rebalance the cluster
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

.PHONY: movies/create-bucket
movies/create-bucket: ##@movies Create bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli bucket-create -c localhost:8091 \
		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
		--bucket $$COUCHBASE_BUCKET \
		--bucket-ramsize $$COUCHBASE_BUCKET_RAMSIZE \
		--bucket-type couchbase \
		--wait 

.PHONY: movies/create-scope
movies/create-scope: ##@movies Create scope within the bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli collection-manage  -c localhost:8091 \
		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
		--bucket $$COUCHBASE_BUCKET \
		--create-scope sample

.PHONY: movies/create-collection
movies/create-collection: ##@movies Create collection within scope
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli collection-manage  -c localhost:8091 \
		--username $$COUCHBASE_ADMINISTRATOR_USERNAME \
		--password $$COUCHBASE_ADMINISTRATOR_PASSWORD \
		--bucket $$COUCHBASE_BUCKET \
		--create-collection sample.movies

.PHONY: movies/create-indexes
movies/create-indexes: ##@movies Create indexes
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/curl -v http://localhost:8093/query/service \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD \
		-d 'statement=CREATE PRIMARY INDEX `#primary` ON `playground`.`sample`.`movies`'

	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/curl -v http://localhost:8093/query/service \
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
	./bin/curl -v http://localhost:8093/query/service \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD \
		-d "statement=SELECT * FROM playground.sample.movies AS movies WHERE ANY v IN genres SATISFIES v = 'Comedy' END LIMIT 10"

.PHONY: sample/import-cb-sample
sample/import-cb-sample: ##@sample Import sample data from CB
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/curl -v http://localhost:8091/sampleBuckets/install \
		-u $$COUCHBASE_ADMINISTRATOR_USERNAME:$$COUCHBASE_ADMINISTRATOR_PASSWORD \
		-d '["gamesim-sample","travel-sample", "beer-sample"]'

### MISC

.PHONY: init
init: tls/create-cert network/create tls/trust-cert dns/insert## Running init tasks
	@echo "Init completed"

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