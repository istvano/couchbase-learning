.PHONY: sec/password/rotate_internal
sec/password/rotate_internal: ##@security Rotate internal passwords in the cluster
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/node/controller/rotateInternalCredentials \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X POST

.PHONY: sec/certs/client
sec/certs/client: ##@security Get client certificates
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/certificates/client \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X GET | jq

.PHONY: sec/certs/node
sec/certs/node: ##@security Get certificates
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/certificates \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X GET | jq

.PHONY: sec/certs/ca
sec/certs/ca: ##@security Get trusted ca certs
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/trustedCAs \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X GET | jq

.PHONY: sec/netshoot
sec/netshoot: ##@security Listening on the looback interface
	$(DOCKER) run -it --net=container:$(APP)_$(MAIN_NODE) \
	nicolaka/netshoot

.PHONY: sec/tcpdump
sec/tcpdump: ##@security Listening on the looback interface for Auth events
	$(DOCKER) run -it --net=container:$(APP)_$(MAIN_NODE) \
	nicolaka/netshoot \
	tcpdump -i lo -lA | grep "Authorization: Basic"

.PHONY: sec/nmap
sec/nmap: ##@security Check open ports
	$(DOCKER) run -it --net=container:$(APP)_$(MAIN_NODE) \
	nicolaka/netshoot \
	nmap -sC -sV -Pn -p0-65535 127.0.0.1 -oN server_report