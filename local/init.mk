
CRT_FILENAME?=tls.pem
KEY_FILENAME?=tls.key

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
