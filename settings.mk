.PHONY: settings/security
settings/security: ##@Settings Show settings for security
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/security \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD 

.PHONY: settings/certs/client
settings/certs/client: ##@Settings Show settings for client auth
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/clientCertAuth \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD

.PHONY: settings/saml
settings/saml: ##@Settings Show SAML settings
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/saml \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq -S

.PHONY: settings/saml/load
settings/saml/load: ##@Settings Load SAML settings from json, you need to replace the key in spKey
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/saml \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-H "Content-Type:application/json" \
		-d @../etc/saml_settings.json

.PHONY: settings/saml/save
settings/saml/save: ##@Settings Save SAML settings
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/saml \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-H "Content-Type:application/json" | jq \
		'del(.spMetadataURL, .spLogoutURL, .spConsumeURL, .idpMetadataTLSExtraOpts)' \
		>../etc/saml_settings.json

.PHONY: settings/clientcert/load
settings/clientcert/load: ##@Settings Load Client Cert Auth settings
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/clientCertAuth \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-H "Content-Type:application/json" \
		-d @../etc/clientcert_settings.json

.PHONY: settings/clientcert/save
settings/clientcert/save: ##@Settings Save Client Cert Auth settings
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/clientCertAuth \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-H "Content-Type:application/json" | jq \
		>../etc/clientcert_settings.json

# curl -v -X POST http://10.143.192.102:8091/settings/clientCertAuth \
# --data-binary @client-auth-settings.json \
# -u Administrator:password

.PHONY: settings/developerprev/enable
settings/developerprev/enable: ##@Settings Enable developer preview mode
	$(CURL) $(CURL_OPTS) -X POST $(API_ENDPOINT)/settings/developerPreview  \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d 'enabled=true'

.PHONY: settings/developerprev/status
settings/developerprev/status: ##@Settings Check developer preview status
	$(CURL) --silent $(CURL_OPTS) $(API_ENDPOINT)/pools  \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq . | grep Preview

.PHONY: settings/oauthbearer/enable
settings/oauthbearer/enable: ##@Settings Enable OAUTHBEARER SASL
	$(CURL) $(CURL_OPTS) -X POST $(API_ENDPOINT)/settings/security  \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d 'oauthBearerEnabled=true' 

.PHONY: settings/oauthbearer/status
settings/oauthbearer/status: ##@Settings Check OAUTHBEARER status
	$(CURL) --silent $(CURL_OPTS) $(API_ENDPOINT)/settings/security  \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq . | grep oauthBearerEnabled

