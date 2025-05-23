.PHONY: tls/server/testssl
tls/server/testssl: ##@tls Check compliance with testssl
	$(DOCKER) run --rm -ti  drwetter/testssl.sh --severity LOW --show-each --parallel 	--wide $(INTERNAL_ENDPOINT):$(CONNECT_ENDPOINT_TLS_PORT)

.PHONY: tls/server/testssl/ciphers
tls/server/testssl/ciphers: ##@tls Check compliance with testssl ciphers only
	$(DOCKER) run --rm -ti  drwetter/testssl.sh --severity LOW --show-each --parallel 	--wide --cipher-per-proto $(INTERNAL_ENDPOINT):$(CONNECT_ENDPOINT_TLS_PORT)


.PHONY: tls/server/sslyze
tls/server/sslyze: ##@tls Check compliance with sslyze
	$(DOCKER) run --rm -ti nablac0d3/sslyze:6.1.0 $(INTERNAL_DOMAIN):$(CONNECT_ENDPOINT_TLS_PORT)

.PHONY: tls/server/cipher-check-nmap
tls/server/cipher-check-nmap: ##@tls Check ciphers with nmap
# nmap --script ssl-enum-ciphers -p 18092 $(CONNECT_ENDPOINT)	
	nmap --script ssl-enum-ciphers -p $(CONNECT_ENDPOINT_TLS_PORT) $(CONNECT_ENDPOINT)

.PHONY: tls/server/cipher-check
tls/server/cipher-check: ##@tls Check ciphers with nmap
	../etc/tls/ciphers.sh $(CONNECT_ENDPOINT) $(CONNECT_ENDPOINT_TLS_PORT)

.PHONY: tls/server/certs/regenerate
tls/server/certs/regenerate: ##@tls Regenerate certs
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/controller/regenerateCertificate \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X POST

.PHONY: tls/server/certs/client
tls/server/certs/client: ##@tls Get client certificates
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/certificates/client \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X GET | jq

.PHONY: tls/server/certs/client/details
tls/server/certs/client/details: ##@tls Get client certificates details
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/certificates/client \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X GET | jq -r '.[0].pem' | openssl x509 -text

.PHONY: tls/server/certs/node
tls/server/certs/node: ##@tls Get node certificate
	@(IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/certificate/node/$$IP \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X GET | jq)
	

.PHONY: tls/server/certs/node/details
tls/server/certs/node/details: ##@tls Get node certificate details
	@(IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/certificate/node/$$IP \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X GET | jq -r .pem | openssl x509 -text)

.PHONY: tls/server/certs/ca
tls/server/certs/ca: ##@tls Get trusted ca certs
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/trustedCAs \
		--insecure \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X GET | jq

.PHONY: tls/server/certs/ca/details
tls/server/certs/ca/details: ##@security Get trusted ca certs details
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/trustedCAs \
		--insecure \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X GET | jq -r '.[0].pem' | openssl x509 -text

.PHONY: tls/server/set-min-ver/v2
tls/server/set-min-ver/v2: ##@tls Set min-version 1.2
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli setting-security \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--set \
		--tls-min-version tlsv1.2

.PHONY: tls/server/set-min-ver/v3
tls/server/set-min-ver/v3: ##@tls Set min-version 1.3
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli setting-security \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--set \
		--tls-min-version tlsv1.3

.PHONY: tls/ciphers
tls/cihers: ##@tls List all available ciphers in openssl
	openssl  ciphers -v

.PHONY: tls/server/check-tls-ver/v2
tls/server/check-tls-ver/v2: ##@tls Check if we can connect with tls 1.2
	openssl s_client -connect $(CONNECT_ENDPOINT):$(CONNECT_ENDPOINT_TLS_PORT) -tls1_2 -cipher $(CIPHER_V2)

.PHONY: tls/server/check-tls-ver/v3
tls/server/check-tls-ver/v3: ##@tls Check if we can connect with tls 1.3
	openssl s_client -connect $(CONNECT_ENDPOINT):$(CONNECT_ENDPOINT_TLS_PORT) -tls1_3 -ciphersuites $(CIPHER_V3)

.PHONY: tls/server/set-enc-level/strict
tls/server/set-enc-level/strict: ##@tls Set encryption level strict
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli setting-security \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--set \
		--cluster-encryption-level strict

.PHONY: tls/server/set-enc-level/all
tls/server/set-enc-level/all: ##@tls Set encryption level all
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli setting-security \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--set \
		--cluster-encryption-level all

.PHONY: tls/server/node2node/enable
tls/server/node2node/enable: ##@tls enable cluster node 2 node encryption
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli node-to-node-encryption \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--enable

.PHONY: tls/server/node2node/disable
tls/server/node2node/disable: ##@tls disable cluster node 2 node encryption
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli node-to-node-encryption \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--disable

.PHONY: tls/server/autofailover/disable
tls/server/autofailover/disable: ##@tls Disable auto failover
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli setting-autofailover \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--enable-auto-failover 0

.PHONY: tls/server/autofailover/enable
tls/server/autofailover/enable: ##@tls Disable auto failover
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli setting-autofailover \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--enable-auto-failover 1

.PHONY: tls/server/get-security-info
tls/server/get-security-info: ##@tls Get security information
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/security \
		--insecure \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X GET | jq "."

.PHONY: tls/server/cipher-list
tls/server/cipher-list: ##@tls Supported ciphers
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/security \
		--insecure \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X GET | jq -r '.data.supportedCipherSuites | join(",")'

.PHONY: tls/server/data/get-security-info
tls/server/data/get-security-info: ##@tls Get security information
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/security/data \
		--insecure \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X GET | jq "."

.PHONY: tls/server/get-cipher-info
tls/server/get-cipher-info: ##@tls Get security information
	@$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli setting-security \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--get


.PHONY: tls/server/set-cipher-suites
tls/server/set-cipher-suites: ##@tls Set ciphers
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli setting-security \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--set \
		--tls-honor-cipher-order 1 \
		--cipher-suites "TLS_AES_128_GCM_SHA256,TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256"
		#--cipher-suites "TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256,TLS_AES_128_GCM_SHA256" \
		#--cipher-suites "TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256,TLS_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_DHE_DSS_WITH_AES_256_GCM_SHA384,TLS_DHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256" \
		#--cipher-suites "TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256,TLS_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_DHE_DSS_WITH_AES_256_GCM_SHA384,TLS_DHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256,TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,TLS_DHE_RSA_WITH_CHACHA20_POLY1305_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_CCM_8,TLS_ECDHE_ECDSA_WITH_AES_256_CCM,TLS_DHE_RSA_WITH_AES_256_CCM_8,TLS_DHE_RSA_WITH_AES_256_CCM,TLS_ECDHE_ECDSA_WITH_ARIA_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_ARIA_256_GCM_SHA384,TLS_DHE_DSS_WITH_ARIA_256_GCM_SHA384,TLS_DHE_RSA_WITH_ARIA_256_GCM_SHA384,TLS_DH_anon_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_DHE_DSS_WITH_AES_128_GCM_SHA256,TLS_DHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_128_CCM_8,TLS_ECDHE_ECDSA_WITH_AES_128_CCM,TLS_DHE_RSA_WITH_AES_128_CCM_8,TLS_DHE_RSA_WITH_AES_128_CCM,TLS_ECDHE_ECDSA_WITH_ARIA_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_ARIA_128_GCM_SHA256,TLS_DHE_DSS_WITH_ARIA_128_GCM_SHA256,TLS_DHE_RSA_WITH_ARIA_128_GCM_SHA256,TLS_DH_anon_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384,TLS_DHE_RSA_WITH_AES_256_CBC_SHA256,TLS_DHE_DSS_WITH_AES_256_CBC_SHA256,TLS_ECDHE_ECDSA_WITH_CAMELLIA_256_CBC_SHA384,TLS_ECDHE_RSA_WITH_CAMELLIA_256_CBC_SHA384,TLS_DHE_RSA_WITH_CAMELLIA_256_CBC_SHA256,TLS_DHE_DSS_WITH_CAMELLIA_256_CBC_SHA256,TLS_DH_anon_WITH_AES_256_CBC_SHA256,TLS_DH_anon_WITH_CAMELLIA_256_CBC_SHA256,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256,TLS_DHE_RSA_WITH_AES_128_CBC_SHA256,TLS_DHE_DSS_WITH_AES_128_CBC_SHA256,TLS_ECDHE_ECDSA_WITH_CAMELLIA_128_CBC_SHA256,TLS_ECDHE_RSA_WITH_CAMELLIA_128_CBC_SHA256,TLS_DHE_RSA_WITH_CAMELLIA_128_CBC_SHA256,TLS_DHE_DSS_WITH_CAMELLIA_128_CBC_SHA256,TLS_DH_anon_WITH_AES_128_CBC_SHA256,TLS_DH_anon_WITH_CAMELLIA_128_CBC_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA,TLS_DHE_RSA_WITH_AES_256_CBC_SHA,TLS_DHE_DSS_WITH_AES_256_CBC_SHA,TLS_DHE_RSA_WITH_CAMELLIA_256_CBC_SHA,TLS_DHE_DSS_WITH_CAMELLIA_256_CBC_SHA,TLS_ECDH_anon_WITH_AES_256_CBC_SHA,TLS_DH_anon_WITH_AES_256_CBC_SHA,TLS_DH_anon_WITH_CAMELLIA_256_CBC_SHA,TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA,TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA,TLS_DHE_RSA_WITH_AES_128_CBC_SHA,TLS_DHE_DSS_WITH_AES_128_CBC_SHA,TLS_DHE_RSA_WITH_CAMELLIA_128_CBC_SHA,TLS_DHE_DSS_WITH_CAMELLIA_128_CBC_SHA,TLS_ECDH_anon_WITH_AES_128_CBC_SHA,TLS_DH_anon_WITH_AES_128_CBC_SHA,TLS_DH_anon_WITH_CAMELLIA_128_CBC_SHA,TLS_DHE_PSK_WITH_AES_256_GCM_SHA384,TLS_DHE_PSK_WITH_CHACHA20_POLY1305_SHA256,TLS_ECDHE_PSK_WITH_CHACHA20_POLY1305_SHA256,TLS_PSK_DHE_WITH_AES_256_CCM_8,TLS_DHE_PSK_WITH_AES_256_CCM,TLS_DHE_PSK_WITH_ARIA_256_GCM_SHA384,TLS_RSA_WITH_AES_256_GCM_SHA384,TLS_RSA_WITH_AES_256_CCM_8,TLS_RSA_WITH_AES_256_CCM,TLS_RSA_WITH_ARIA_256_GCM_SHA384,TLS_PSK_WITH_AES_256_GCM_SHA384,TLS_PSK_WITH_CHACHA20_POLY1305_SHA256,TLS_PSK_WITH_AES_256_CCM_8,TLS_PSK_WITH_AES_256_CCM,TLS_PSK_WITH_ARIA_256_GCM_SHA384,TLS_DHE_PSK_WITH_AES_128_GCM_SHA256,TLS_PSK_DHE_WITH_AES_128_CCM_8,TLS_DHE_PSK_WITH_AES_128_CCM,TLS_DHE_PSK_WITH_ARIA_128_GCM_SHA256,TLS_RSA_WITH_AES_128_GCM_SHA256,TLS_RSA_WITH_AES_128_CCM_8,TLS_RSA_WITH_AES_128_CCM,TLS_RSA_WITH_ARIA_128_GCM_SHA256,TLS_PSK_WITH_AES_128_GCM_SHA256,TLS_PSK_WITH_AES_128_CCM_8,TLS_PSK_WITH_AES_128_CCM,TLS_PSK_WITH_ARIA_128_GCM_SHA256,TLS_RSA_WITH_AES_256_CBC_SHA256,TLS_RSA_WITH_CAMELLIA_256_CBC_SHA256,TLS_RSA_WITH_AES_128_CBC_SHA256,TLS_RSA_WITH_CAMELLIA_128_CBC_SHA256,TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA384,TLS_ECDHE_PSK_WITH_AES_256_CBC_SHA,TLS_SRP_SHA_DSS_WITH_AES_256_CBC_SHA,TLS_SRP_SHA_RSA_WITH_AES_256_CBC_SHA,TLS_SRP_SHA_WITH_AES_256_CBC_SHA,TLS_DHE_PSK_WITH_AES_256_CBC_SHA384,TLS_DHE_PSK_WITH_AES_256_CBC_SHA,TLS_ECDHE_PSK_WITH_CAMELLIA_256_CBC_SHA384,TLS_DHE_PSK_WITH_CAMELLIA_256_CBC_SHA384,TLS_RSA_WITH_AES_256_CBC_SHA,TLS_RSA_WITH_CAMELLIA_256_CBC_SHA,TLS_PSK_WITH_AES_256_CBC_SHA384,TLS_PSK_WITH_AES_256_CBC_SHA,TLS_PSK_WITH_CAMELLIA_256_CBC_SHA384,TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA256,TLS_ECDHE_PSK_WITH_AES_128_CBC_SHA,TLS_SRP_SHA_DSS_WITH_AES_128_CBC_SHA,TLS_SRP_SHA_RSA_WITH_AES_128_CBC_SHA,TLS_SRP_SHA_WITH_AES_128_CBC_SHA,TLS_DHE_PSK_WITH_AES_128_CBC_SHA256,TLS_DHE_PSK_WITH_AES_128_CBC_SHA,TLS_ECDHE_PSK_WITH_CAMELLIA_128_CBC_SHA256,TLS_DHE_PSK_WITH_CAMELLIA_128_CBC_SHA256,TLS_RSA_WITH_AES_128_CBC_SHA,TLS_RSA_WITH_CAMELLIA_128_CBC_SHA,TLS_PSK_WITH_AES_128_CBC_SHA256,TLS_PSK_WITH_AES_128_CBC_SHA,TLS_PSK_WITH_CAMELLIA_128_CBC_SHA256"
		#--cipher-suites "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384"
		#--cipher-suites "TLS_RSA_PSK_WITH_AES_128_GCM_SHA256 TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256,TLS_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,TLS_DHE_DSS_WITH_AES_256_GCM_SHA384,TLS_DHE_RSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256" \

.PHONY: tls/server/reset-cipher-suites
tls/server/reset-cipher-suites: ##@tls reset ciphers
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli reset-cipher-suites \
		--config-path /opt/couchbase/var/lib/couchbase

### CERTS

.PHONY: tls/client/create-user
tls/client/create-user:  ##@tls Create tls client user
	@echo "Creating self signed CA Private key"
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli \
		user-manage --cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--set \
		--rbac-username client.user@localhost.lan \
		--rbac-password $$COUCHBASE_PASSWORD \
		--roles ro_admin \
		--auth-domain local

.PHONY: tls/client/test
tls/client/test: ##@tls Get CPU stats using certificate authentication
	curl --insecure -vvv --cacert $(TLS)/rootCA.pem --cert $(TLS)/client-user.cert.pem --key $(TLS)/$(KEY_FILENAME) -X GET $(CURL_OPTS) https://localhost:18091/pools/default/stats/range/sysproc_cpu_utilization?proc=ns_server&start=-5

.PHONY: tls/client/create
tls/client/create:  ##@tls Create self sign certs for local machine
	@echo "Creating client signed certificate request"
	openssl req -new -key $(TLS)/$(KEY_FILENAME) -out $(TLS)/client-user.csr -subj "/CN=clientuser"
	@echo "Creating client signed certificate"
	openssl x509 -CA $(TLS)/rootCA.pem -CAkey $(TLS)/rootCA-key.pem \
		-CAcreateserial -days 365 -req -in $(TLS)/client-user.csr \
		-out $(TLS)/client-user.cert.pem -extfile $(TLS)/client.ext
	rm $(TLS)/client-user.csr
	@echo "Client certificate has been created"

.PHONY: tls/client/verify
tls/client/verify:  ##@tls Verify client certificate using CA
	@echo "Verifying certificate:"
	openssl verify -trusted $(TLS)/rootCA.pem $(TLS)/client-user.cert.pem

.PHONY: tls/client/show
tls/client/show:  ##@tls Show client certificate details
	@echo "Verifying certificate:"
	openssl x509 -in $(TLS)/client-user.cert.pem -text

.PHONY: tls/ca/copy
tls/ca/copy:  ##@tls Copy CA cert into the container
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) bash -c "mkdir -p /opt/couchbase/var/lib/couchbase/inbox/CA"
	$(DOCKER) cp $(TLS)/rootCA.pem $(APP)_$(MAIN_NODE):/opt/couchbase/var/lib/couchbase/inbox/CA/clientCA.pem

.PHONY: tls/ca/load
tls/ca/load: ##@tls Load trusted CAs
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/node/controller/loadTrustedCAs \
		--insecure \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X POST

.PHONY: tls/ca/show
tls/ca/show:  ##@tls Show client certificate details
	@echo "Verifying certificate:"
	openssl x509 -in $(TLS)/rootCA.pem -text

.PHONY: tls/ca/create
tls/ca/create:  ##@tls Create self sign certs for local machine
	@echo "Creating self signed CA Private key"
	openssl genrsa -out $(TLS)/rootCA-key.pem 2048
	@echo "Creating self signed CA certificate"
	openssl req -new -x509 -days 3650 -sha512 -key $(TLS)/rootCA-key.pem -out $(TLS)/rootCA.pem -nodes -subj "/CN=Acme Root CA"

.PHONY: tls/ca/delete
tls/ca/delete: ##@tls delete self sign certs for local machine
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

.PHONY: tls/ca/trust
tls/ca/trust: tls/ca/delete ##@tls Trust self signed cert by local browser
	@echo "Import self signed cert into user's truststore"
ifeq ($(UNAME_S),Darwin)
	sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain $(TLS)/rootCA.pem
else
	@[ -d ~/.pki/nssdb ] || mkdir -p ~/.pki/nssdb
	@certutil -d sql:$$HOME/.pki/nssdb -A -n '$(MAIN_DOMAIN) cert authority' -i $(TLS)/rootCA.pem -t TCP,TCP,TCP
	@certutil -d sql:$$HOME/.pki/nssdb -A -n '$(MAIN_DOMAIN)' -i $(TLS)/tls.pem -t P,P,P
endif
	@echo "Import successful..."
