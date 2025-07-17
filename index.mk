.PHONY: bucket/index/info
bucket/index/info: ##@bucket Get all index info
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/indexStatus \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-H "Content-Type: application/json" | jq .