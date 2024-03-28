### Observability

.PHONY: prom/discovery
prom/discovery: ##@observe Prometheus discovery endpoint
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/prometheus_sd_config \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq	