### Observability

.PHONY: prom/discovery
prom/discovery: ##@observe Prometheus discovery endpoint
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/prometheus_sd_config \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq	

.PHONY: cluster/default
cluster/default: ##@cluster Get default cluster information
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq	


.PHONY: cluster/pools
cluster/pools: ##@cluster Get cluster information
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq	

.PHONY: cluster/info
cluster/info: ##@cluster Get Orchestrator information
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/terseClusterInfo \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq	

.PHONY: cluster/nodes
cluster/nodes: ##@cluster Get Nodes
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/nodes \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq	

.PHONY: cluster/node/services
cluster/node/services: ##@cluster Get Node services
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/nodeServices \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq	

.PHONY: cluster/node/eval
cluster/node/eval: ##@cluster Run diag eval to increase the max prefixes for TLS
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -X POST $(API_ENDPOINT)/diag/eval \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d "ns_config:set({menelaus_web_cert, max_prefixes}, 100)"

.PHONY: prom/metrics
prom/metrics: ##@observe Prometheus metrics example
	$(CURL) $(CURL_OPTS) -X POST $(API_ENDPOINT)/pools/default/stats/range \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d '[\
		{\
			"metric": [\
			{"label": "name", "value": "sysproc_cpu_utilization"},\
			{"label": "proc", "value": "indexer"}\
			],\
			"applyFunctions": ["avg"],\
			"alignTimestamps": true,\
			"step": 15,\
			"start": -60\
		},\
		{\
			"metric": [\
			{"label": "name", "value": "kv_disk_write_queue"},\
			{"label": "bucket", "value": "travel-sample"}\
			],\
			"applyFunctions": ["sum"],\
			"step": 60,\
			"start": -300\
		}]' | jq '.'
