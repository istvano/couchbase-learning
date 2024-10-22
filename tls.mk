.PHONY: tls/test
tls/test: ##@tls Check nist compliance
	$(DOCKER) run --rm -ti  drwetter/testssl.sh $(ENDPOINT)

.PHONY: stat/cpu
stat/cpu: ##@stat Get CPU stats using certificate authentication
	curl --insecure -vvv --cacert $(TLS)/.local/share/mkcert/rootCA.pem --cert $(TLS)/client-user.cert.pem --key $(TLS)/$(KEY_FILENAME) -X GET $(CURL_OPTS) $(API_ENDPOINT)/pools/default/stats/range/sysproc_cpu_utilization?proc=ns_server&start=-5


.PHONY: tls/set-min-version
tls/set-min-version: ##@tls Set min-version
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli setting-security \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--set \
		--tls-min-version tlsv1.2

.PHONY: tls/set-enc-level-strict
tls/set-enc-level-strict: ##@tls Set encryption level strict
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli setting-security \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--set \
		--cluster-encryption-level strict

.PHONY: tls/set-enc-level-all
tls/set-enc-level-all: ##@tls Set encryption level all
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli setting-security \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--set \
		--cluster-encryption-level all

.PHONY: tls/node2node/enable
tls/node2node/enable: ##@tls enable cluster node 2 node encryption
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli node-to-node-encryption \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--enable

.PHONY: tls/autofailover/disable
tls/autofailover/disable: ##@tls Disable auto failover
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli setting-autofailover \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--enable-auto-failover 0

.PHONY: tls/get-cipher-info
tls/get-cipher-info: ##@tls Get security information
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli setting-security \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--get | jq



.PHONY: tls/set-cipher-suites
tls/set-cipher-suites: ##@tls Set ciphers
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli setting-security \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--set \
		--tls-honor-cipher-order 1 \
		--cipher-suites "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256"
	| jq 


/opt/couchbase/bin/couchbase-cli setting-security -c sd-fxif-3vtm.nam.nsroot.net:8091 -u Administrator -p password 	

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

.PHONY: tls/create-client-cert
tls/create-client-cert:  ##@tls Create self sign certs for local machine
	@echo "Creating client signed certificate request"
	openssl req -new -key $(TLS)/$(KEY_FILENAME) -out $(TLS)/client-user.csr -subj "/CN=clientuser"
	@echo "Creating client signed certificate"
	openssl x509 -CA $(TLS)/.local/share/mkcert/rootCA.pem -CAkey $(TLS)/.local/share/mkcert/rootCA-key.pem \
		-CAcreateserial -days 365 -req -in $(TLS)/client-user.csr \
		-out $(TLS)/client-user.cert.pem -extfile $(TLS)/client.ext
	rm $(TLS)/client-user.csr
	@echo "Client certificate has been created"
	@echo "Verifying certificate:"
	openssl verify -trusted $(TLS)/.local/share/mkcert/rootCA.pem $(TLS)/client-user.cert.pem

.PHONY: tls/copy-ca
tls/copy-ca:  ##@tls Copy CA cert into the container
	docker exec -it $(APP)_$(MAIN_NODE) bash -c "mkdir -p /opt/couchbase/var/lib/couchbase/inbox/CA"
	docker cp $(TLS)/.local/share/mkcert/rootCA.pem $(APP)_$(MAIN_NODE):/opt/couchbase/var/lib/couchbase/inbox/CA/clientCA.pem

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