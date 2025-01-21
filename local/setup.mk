### SETUP
.PHONY: setup/create-user
setup/create-user: ##@setup Create User
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli user-manage \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--set \
		--rbac-username $$COUCHBASE_RBAC_USERNAME \
		--rbac-password $$COUCHBASE_RBAC_PASSWORD \
		--roles mobile_sync_gateway[*] \
		--auth-domain local

.PHONY: setup/sample/import
setup/sample/import: ##@sample Import sample data from CB
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/sampleBuckets/install \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d '["gamesim-sample","travel-sample", "beer-sample"]'
	