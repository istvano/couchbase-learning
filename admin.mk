.PHONY: admin/gc
admin/gc: ##@admin Invoke garbage collection
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT_QUERY)/admin/gc \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X GET

.PHONY: admin/ffdc
admin/ffdc: ##@admin Invoke ffdc
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT_QUERY)/admin/ffdc \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-X POST
