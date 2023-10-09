.PHONY: bucket/info
bucket/info: ##@bucket Get info
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/buckets/travel-sample \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-H "Content-Type: application/json" | jq .

.PHONY: bucket/stream
bucket/stream: ##@bucket Stream
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/bucketsStreaming/travel-sample \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-H "Content-Type: application/json"

