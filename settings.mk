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