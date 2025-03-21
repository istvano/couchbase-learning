
.PHONY: init ## Running init tasks (create tls, dns and network)
init: tls/create-cert tls/trust-cert network/create volume/create ## Running init tasks (create tls, dns and network)
	@echo "Init completed"

.PHONY: cleanup
cleanup: network/delete volume/delete ## Running cleanup tasks tasks (dns and network)
	@echo "Cleanup completed"

### DNS

.PHONY: dns/insert
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

.PHONY: network/createIps
network/createIps: ##@Docker create additional local IPSs
	sudo ifconfig bridge10 create
	sudo ifconfig bridge10 inet 192.168.99.1  netmask 255.255.255.0 up
	sudo ifconfig bridge11 create
	sudo ifconfig bridge11 inet 192.168.99.2  netmask 255.255.255.0 up
	sudo ifconfig bridge12 create
	sudo ifconfig bridge12 inet 192.168.99.3  netmask 255.255.255.0 up
	sudo ifconfig bridge13 create
	sudo ifconfig bridge13 inet 192.168.99.4  netmask 255.255.255.0 up

.PHONY: network/deleteIps
network/deleteIps: ##@Docker create additional local IPSs
	sudo ifconfig bridge10 destroy
	sudo ifconfig bridge11 destroy
	sudo ifconfig bridge12 destroy
	sudo ifconfig bridge13 destroy

.PHONY: volume/create
volume/create: ##@Docker create volume
	@echo "Create Docker volumes ..."
	@for n in $(NODES) ; do \
		echo "Creating volume $(ENV)_couchbase_$$n"; \
		$(DOCKER) volume inspect $(ENV)_couchbase_$$n || $(DOCKER) volume create $(ENV)_couchbase_$$n; \
	done
	@echo "Completed..."

.PHONY: volume/delete
volume/delete: ##@Docker create volume
	@echo "Deleting Docker volumes ..."
	@for n in $(NODES) ; do \
		echo "Deleting volume $(ENV)_couchbase_$$n"; \
		$(DOCKER) volume inspect $(ENV)_couchbase_$$n && $(DOCKER) volume rm $(ENV)_couchbase_$$n; \
	done
	find $(MFILECWD)/../share/logs -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
	find $(MFILECWD)/../share/data -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
	@echo "Completed..."