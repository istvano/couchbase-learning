### SETUP

.PHONY: setup/init
setup/init: ##@setup Init cluster
	@(IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli cluster-init \
		-c couchbase://$$IP \
		--cluster-name $$CLUSTER_NAME \
  		--cluster-username $$COUCHBASE_USERNAME \
  		--cluster-password $$COUCHBASE_PASSWORD \
  		--services data,index,query,fts \
  		--cluster-ramsize $$COUCHBASE_RAM_SIZE \
  		--cluster-index-ramsize $$COUCHBASE_INDEX_RAM_SIZE \
  		--index-storage-setting default \
		--node-to-node-encryption off \
	)

.PHONY: setup/worker/add
setup/worker/add: ##@setup Add workers to an existing cluster
	@(MAIN_IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_east` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-add \
		-c couchbase://$$MAIN_IP \
  		--username $$COUCHBASE_USERNAME \
  		--password $$COUCHBASE_PASSWORD \
		--server-add $$IP \
  		--services data,index,query,fts \
  		--index-storage-setting default \
		--server-add-username $$COUCHBASE_USERNAME \
  		--server-add-password $$COUCHBASE_PASSWORD \
	)
	@(MAIN_IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_west` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-add \
		-c couchbase://$$MAIN_IP \
  		--username $$COUCHBASE_USERNAME \
  		--password $$COUCHBASE_PASSWORD \
		--server-add $$IP \
  		--services data,index,query,fts \
  		--index-storage-setting default \
		--server-add-username $$COUCHBASE_USERNAME \
  		--server-add-password $$COUCHBASE_PASSWORD \
	)

.PHONY: setup/misc/add
setup/misc/add: ##@setup Add misc node to run search,analytics,eventing and backup
	@(MAIN_IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(MAIN_NODE)` \
	&& IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_misc` \
	&& $(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli server-add \
		-c couchbase://$$MAIN_IP \
  		--username $$COUCHBASE_USERNAME \
  		--password $$COUCHBASE_PASSWORD \
		--server-add $$IP \
  		--services backup,eventing,analytics \
  		--index-storage-setting default \
		--server-add-username $$COUCHBASE_USERNAME \
  		--server-add-password $$COUCHBASE_PASSWORD \
	)

.PHONY: setup/cluster-rebalance
setup/rebalance: ##@setup Rebalance the cluster
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli rebalance \
		--cluster http://127.0.0.1 \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \

.PHONY: setup/create-user
setup/create-user: ##@setup Create User
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli user-manage \
		--cluster http://127.0.0.1 \
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
