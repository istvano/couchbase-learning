### Perf
PERFORMANCE_COLLECTION=_default._default
PERFORMANCE_REPLICA=0
PERFORMANCE_INDEX_REPLICA=0
PERFORMANCE_RAMSIZE=1000
PERFORMANCE_BUCKET=performance

YCSB_DOCKER_IMAGE?=ycsb-couchbase
YCSB_RECORDS?=10000000
YCSB_OPERATIONS?=10000000
YCSB_BUCKET?=0
YCSB_NODE?=$(APP)_main

### PERFORMANCE

.PHONY: perf/bucket/create
perf/bucket/create: ##@perf Create bucket for performance tests
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli bucket-create -c $(CONNECT_ENDPOINT):$(CONNECT_ENDPOINT_PORT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--bucket $(PERFORMANCE_BUCKET) \
		--bucket-ramsize $(PERFORMANCE_RAMSIZE) \
		--bucket-replica $(PERFORMANCE_REPLICA) \
  		--enable-flush 1 \
  		--enable-index-replica $(PERFORMANCE_INDEX_REPLICA) \
		--bucket-type couchbase \
		--wait 

.PHONY: perf/bucket/delete
perf/bucket/delete: ##@perf delete the performance tests bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli bucket-delete -c $(CONNECT_ENDPOINT):$(CONNECT_ENDPOINT_PORT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--bucket $(PERFORMANCE_BUCKET)

.PHONY: perf/document/create
perf/document/create: ##@perf delete the performance tests bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/cbworkloadgen -n $(CONNECT_ENDPOINT):$(CONNECT_ENDPOINT_PORT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--bucket $(PERFORMANCE_BUCKET) \
		-i 500000

.PHONY: perf/test/5050
perf/test/5050: ##@perf Start pillowflight test using 50% read and write workloads
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	cbc-pillowfight --spec "couchbases://$(CONNECT_ENDPOINT)/$(PERFORMANCE_BUCKET)?ssl=no_verify&ipv6=allow&enable_tracing=false" -u $$COUCHBASE_USERNAME --password $$COUCHBASE_PASSWORD --timings --batch-size 1 --random-body --random-body-pool-size 100 --num-items 20000000 --num-threads 128 -m 1024 -M 16384 --collection=$(PERFORMANCE_COLLECTION) --json --set-pct 50 --num-cycles 1000000 --durability majority

.PHONY: perf/ycsb/build
perf/ycsb/build: ##@perf Build container for ycsb
	$(DOCKER) build -t $(YCSB_DOCKER_IMAGE)  $(ETC)/ycsb/.

.PHONY: perf/ycsb/build/debug
perf/ycsb/build/debug: ##@perf Build container for ycsb
	DOCKER_BUILDKIT=0 $(DOCKER) build --no-cache -t $(YCSB_DOCKER_IMAGE)  $(ETC)/ycsb/.

# Workload A: Update Heavy Workload
# Operation Mix: 50% reads, 50% updates
# Access Pattern: Uniform or Zipfian distribution
# Purpose: Simulates applications with a balanced mix of read and write operations, such as session stores or user profile updates.

.PHONY: perf/ycsb/runa
perf/ycsb/runa: ##@perf Run workload a (high read/write parity, 50% read, 50% update)
	$(DOCKER) run -it --rm --network $(ENV)_couchbase \
		-v $(ETC)/ycsb/entrypoint.sh:/entrypoint.sh \
		-v $(ETC)/tmp:/ycsb/output \
		-e COUCHBASE_HOSTNAME=$(YCSB_NODE) \
        -e COUCHBASE_USERNAME=$$COUCHBASE_USERNAME \
        -e COUCHBASE_PASSWORD=$$COUCHBASE_PASSWORD \
		-e COUCHBASE_DEBUG=true \
        -e WORKLOAD=a \
        -e RECORDS=$(YCSB_RECORDS) \
        -e OPERATIONS=$(YCSB_OPERATIONS) \
        -e ENABLE_STATS=true \
		-e COUCHBASE_BUCKET_TYPE=$(YCSB_BUCKET) \
        $(YCSB_DOCKER_IMAGE)

# Workload B: Read Mostly Workload
# Operation Mix: 95% reads, 5% updates
# Access Pattern: Uniform or Zipfian distribution
# Purpose: Represents scenarios where applications perform many more reads than writes, such as photo tagging or user-generated content platforms.

.PHONY: perf/ycsb/runb
perf/ycsb/runb: ##@perf Run workload b (reads dominate, 95% reads, 5% updates)
	$(DOCKER) run -it --rm --network $(ENV)_couchbase \
		-v $(ETC)/ycsb/entrypoint.sh:/entrypoint.sh \
		-v $(ETC)/tmp:/ycsb/output \
		-e COUCHBASE_HOSTNAME=$(YCSB_NODE) \
        -e COUCHBASE_USERNAME=$$COUCHBASE_USERNAME \
        -e COUCHBASE_PASSWORD=$$COUCHBASE_PASSWORD \
		-e COUCHBASE_DEBUG=true \
        -e WORKLOAD=b \
        -e RECORDS=$(YCSB_RECORDS) \
        -e OPERATIONS=$(YCSB_OPERATIONS) \
		-e COUCHBASE_BUCKET_TYPE=$(YCSB_BUCKET) \
        -e ENABLE_STATS=true \
        $(YCSB_DOCKER_IMAGE)

# Workload C: Read-Only Workload
# Operation Mix: 100% reads
# Access Pattern: Uniform or Zipfian distribution
# Purpose: Ideal for caching mechanisms and applications where data is static or infrequently updated.

.PHONY: perf/ycsb/runc
perf/ycsb/runc: ##@perf Run workload c (read-only like caching layers, 100% read)
	$(DOCKER) run -it --rm --network $(ENV)_couchbase \
		-v $(ETC)/ycsb/entrypoint.sh:/entrypoint.sh \
		-v $(ETC)/tmp:/ycsb/output \
		-e COUCHBASE_HOSTNAME=$(YCSB_NODE) \
        -e COUCHBASE_USERNAME=$$COUCHBASE_USERNAME \
        -e COUCHBASE_PASSWORD=$$COUCHBASE_PASSWORD \
		-e COUCHBASE_DEBUG=true \
        -e WORKLOAD=c \
        -e RECORDS=$(YCSB_RECORDS) \
        -e OPERATIONS=$(YCSB_OPERATIONS) \
		-e COUCHBASE_BUCKET_TYPE=$(YCSB_BUCKET) \
        -e ENABLE_STATS=true \
        $(YCSB_DOCKER_IMAGE)

# Workload D: Read Latest Workload
# Operation Mix: 95% reads, 5% inserts
# Access Pattern: Latest distribution (bias towards recently inserted records)
# Purpose: Simulates applications like news feeds or timeline updates where the most recent data is accessed more frequently.

.PHONY: perf/ycsb/rund
perf/ycsb/rund: ##@perf Run workload d (prioritize recent data, 95% reads, 5% inserts)
	$(DOCKER) run -it --rm --network $(ENV)_couchbase \
		-v $(ETC)/ycsb/entrypoint.sh:/entrypoint.sh \
		-v $(ETC)/tmp:/ycsb/output \
		-e COUCHBASE_HOSTNAME=$(YCSB_NODE) \
        -e COUCHBASE_USERNAME=$$COUCHBASE_USERNAME \
        -e COUCHBASE_PASSWORD=$$COUCHBASE_PASSWORD \
		-e COUCHBASE_DEBUG=true \
        -e WORKLOAD=d \
        -e RECORDS=$(YCSB_RECORDS) \
        -e OPERATIONS=$(YCSB_OPERATIONS) \
		-e COUCHBASE_BUCKET_TYPE=$(YCSB_BUCKET) \
        -e ENABLE_STATS=true \
        $(YCSB_DOCKER_IMAGE)

# Workload E: Short Ranges
# Operation Mix: 95% scans, 5% inserts
# Access Pattern: Sequential access patterns over a range of records
# Purpose: Represents applications that perform range queries, such as threaded conversations or time-series data.

.PHONY: perf/ycsb/rune
perf/ycsb/rune: ##@perf Run workload e (analytical applications, 95% scans, 5% inserts)
	$(DOCKER) run -it --rm --network $(ENV)_couchbase \
		-v $(ETC)/ycsb/entrypoint.sh:/entrypoint.sh \
		-v $(ETC)/tmp:/ycsb/output \
		-e COUCHBASE_HOSTNAME=$(YCSB_NODE) \
        -e COUCHBASE_USERNAME=$$COUCHBASE_USERNAME \
        -e COUCHBASE_PASSWORD=$$COUCHBASE_PASSWORD \
		-e COUCHBASE_DEBUG=true \
        -e WORKLOAD=e \
        -e RECORDS=$(YCSB_RECORDS) \
        -e OPERATIONS=$(YCSB_OPERATIONS) \
        -e ENABLE_STATS=true \
		-e COUCHBASE_BUCKET_TYPE=$(YCSB_BUCKET) \
        $(YCSB_DOCKER_IMAGE)

# Workload F: Read-Modify-Write
# Operation Mix: 50% read-modify-write transactions
# Access Pattern: Uniform or Zipfian distribution
# Purpose: Simulates transactions that read a record, perform some logic, and write back the changes, common in user settings updates or inventory systems.

.PHONY: perf/ycsb/runf
perf/ycsb/runf: ##@perf Run workload f (transactional integrity, 50% read-modify-write)
	$(DOCKER) run -it --rm --network $(ENV)_couchbase \
		-v $(ETC)/ycsb/entrypoint.sh:/entrypoint.sh \
		-v $(ETC)/tmp:/ycsb/output \
		-e COUCHBASE_HOSTNAME=$(YCSB_NODE) \
        -e COUCHBASE_USERNAME=$$COUCHBASE_USERNAME \
        -e COUCHBASE_PASSWORD=$$COUCHBASE_PASSWORD \
		-e COUCHBASE_DEBUG=true \
        -e WORKLOAD=f \
        -e RECORDS=$(YCSB_RECORDS) \
        -e OPERATIONS=$(YCSB_OPERATIONS) \
		-e COUCHBASE_BUCKET_TYPE=$(YCSB_BUCKET) \
        -e ENABLE_STATS=true \
        $(YCSB_DOCKER_IMAGE)

.PHONY: perf/ycsb/runz
perf/ycsb/runz: ##@perf Run workload z (75% read, 25% write with uniform distribution)
	$(DOCKER) run -it --rm --network $(ENV)_couchbase \
		-v $(ETC)/ycsb/entrypoint.sh:/entrypoint.sh \
		-v $(ETC)/tmp:/ycsb/output \
		-e COUCHBASE_HOSTNAME=$(YCSB_NODE) \
        -e COUCHBASE_USERNAME=$$COUCHBASE_USERNAME \
        -e COUCHBASE_PASSWORD=$$COUCHBASE_PASSWORD \
		-e COUCHBASE_DEBUG=true \
        -e WORKLOAD=z \
        -e RECORDS=$(YCSB_RECORDS) \
        -e OPERATIONS=$(YCSB_OPERATIONS) \
		-e COUCHBASE_BUCKET_TYPE=$(YCSB_BUCKET) \
        -e ENABLE_STATS=true \
        $(YCSB_DOCKER_IMAGE)

.PHONY: perf/ycsb/runzz
perf/ycsb/runzz: ##@perf Run workload zz (75% read, 25% write with uniform distribution)
	$(DOCKER) run -it --rm --network $(ENV)_couchbase \
		-v $(ETC)/ycsb/entrypoint.sh:/entrypoint.sh \
		-v $(ETC)/tmp:/ycsb/output \
		-e COUCHBASE_HOSTNAME=$(YCSB_NODE) \
        -e COUCHBASE_USERNAME=$$COUCHBASE_USERNAME \
        -e COUCHBASE_PASSWORD=$$COUCHBASE_PASSWORD \
		-e COUCHBASE_DEBUG=true \
        -e WORKLOAD=zz \
        -e RECORDS=$(YCSB_RECORDS) \
        -e OPERATIONS=$(YCSB_OPERATIONS) \
		-e COUCHBASE_BUCKET_TYPE=$(YCSB_BUCKET) \
        -e ENABLE_STATS=true \
        $(YCSB_DOCKER_IMAGE)

# Use Cases:

# Workload A: Suitable for applications with high read/write parity like session stores.
# Workload B: Ideal for content browsing applications where reads dominate.
# Workload C: Perfect for read-only scenarios like caching layers.
# Workload D: Matches applications that prioritize recent data, such as social media feeds.
# Workload E: Fits analytical applications requiring range scans.
# Workload F: Relevant for systems requiring transactional integrity during updates.