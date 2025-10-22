XDCR_NODE=xdcr

.PHONY: xdcr/up
xdcr/up: ##@xdcr Start docker container
	$(DOCKER) run -it -d --rm \
		--env-file=./.env \
		--network $(ENV)_couchbase \
		--name="$(APP)_$(XDCR_NODE)" \
		-w /opt/couchbase \
		-p 7091-7094:8091-8094  \
		-p 10210:11210  \
		-p 17091-17094:18091-18094  \
		--health-cmd "$(CURL) --fail $(API_ENDPOINT)/ui/index.html || exit 1" --health-interval=5s --health-timeout=3s --health-retries=10 --health-start-period=5s \
		$(DOCKER_IMAGE):$(VERSION)

.PHONY: xdcr/down
xdcr/down: ##@xdcr Kill docker container
	$(DOCKER) stop "$(APP)_$(XDCR_NODE)"

.PHONY: xdcr/init
xdcr/init: ##@xdcr Init cluster
	@(IP=`$(DOCKER) inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(APP)_$(XDCR_NODE)` \
	&& $(DOCKER) exec -it $(APP)_$(XDCR_NODE) \
	./bin/couchbase-cli cluster-init \
		-c couchbase://$$IP \
		--cluster-name xdcr_cluster \
  		--cluster-username $$COUCHBASE_USERNAME \
  		--cluster-password $$COUCHBASE_PASSWORD \
  		--services $(SERVICES) \
  		--cluster-ramsize $$COUCHBASE_RAM_SIZE \
  		--cluster-index-ramsize $$COUCHBASE_INDEX_RAM_SIZE \
  		--index-storage-setting default)


.PHONY: setup/sample/import
xdcr/sample/import: ##@xdcr Import sample data for xdcr node
	$(DOCKER) exec -it $(APP)_$(XDCR_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/sampleBuckets/install \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d '["travel-sample"]'

.PHONY: xdcr/setup/remote/create
xdcr/setup/remote/create: ##@xdcr Import sample data for xdcr node
	$(DOCKER) exec -it $(APP)_$(XDCR_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/pools/default/remoteClusters \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
  		--data-raw 'name=$(CLUSTER_NAME)&hostname=$(APP)_$(MAIN_NODE)%3A8091&username=Administrator&password=password'

.PHONY: xdcr/bucket/create-replicated
xdcr/bucket/create-replicated: ##@xdcr Create 'travel-sample-replicated' bucket
	$(DOCKER) exec -it $(APP)_$(XDCR_NODE) \
	$(CURL) $(CURL_OPTS) -X POST $(API_ENDPOINT)/pools/default/buckets \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-H "Content-Type: application/x-www-form-urlencoded" \
		--data-urlencode name=travel-sample-replicated \
		--data-urlencode bucketType=couchbase \
		--data-urlencode ramQuotaMB=256 \
		--data-urlencode replicaNumber=1 \
		--data-urlencode storageBackend=couchstore \
		--data-urlencode flushEnabled=0 \
		--data-urlencode evictionPolicy=valueOnly \
		--data-urlencode durabilityMinLevel=none \
		--data-urlencode conflictResolutionType=seqno