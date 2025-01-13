.PHONY: sec/password/rotate_internal
sec/password/rotate_internal: ##@security Rotate internal passwords in the cluster
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/node/controller/rotateInternalCredentials \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X POST

.PHONY: sec/password/policy_no_user
sec/password/policy_no_user: ##@security Change password policy for an uninitialized cluster
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/settings/passwordPolicy \
		-X POST \
		-d minLength=32 \
		-d enforceUppercase=false \
		-d enforceLowercase=false \
		-d enforceDigits=false \
		-d enforceSpecialChars=false

.PHONY: sec/password/policy
sec/password/policy: ##@security Change password policy with initialized cluster
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/settings/passwordPolicy \
		-X POST \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d minLength=8 \
		-d enforceUppercase=false \
		-d enforceLowercase=false \
		-d enforceDigits=false \
		-d enforceSpecialChars=false

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

.PHONY: sec/audit/config/get
sec/audit/config/get: ##@security Copy the audit_events.json to etc
	$(DOCKER) cp $(APP)_$(MAIN_NODE):/opt/couchbase/etc/security/audit_events.json $(MFILECWD)/../etc/audit_events.json

.PHONY: sec/audit/config/put
sec/audit/config/put: ##@security Copy the audit_events.json back
	$(DOCKER) cp $(MFILECWD)/../etc/audit_events.json $(APP)_$(MAIN_NODE):/opt/couchbase/etc/security/audit_events.json

.PHONY: sec/audit/config/reload
sec/audit/config/reload: ##@security Reload audit config data
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
		$(CURL) $(API_ENDPOINT)/diag/eval \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d "[{set, _, X}] = ns_audit_cfg:upgrade_descriptors(), ns_config:set(audit_decriptors, lists:ukeysort(1, X))." \
		-X POST