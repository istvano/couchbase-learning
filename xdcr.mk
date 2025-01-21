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
		--cluster-name $$CLUSTER_NAME \
  		--cluster-username $$COUCHBASE_USERNAME \
  		--cluster-password $$COUCHBASE_PASSWORD \
  		--services data,index,query,fts \
  		--cluster-ramsize $$COUCHBASE_RAM_SIZE \
  		--cluster-index-ramsize $$COUCHBASE_INDEX_RAM_SIZE \
  		--index-storage-setting default)
		