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

### MOVIES

.PHONY: movies/bucket/create
movies/bucket/create: ##@movies Create bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli bucket-create -c localhost:8091 \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--bucket $$COUCHBASE_BUCKET \
		--bucket-ramsize $$COUCHBASE_BUCKET_RAMSIZE \
		--bucket-type couchbase \
		--wait 

.PHONY: movies/scope/create
movies/scope/create: ##@movies Create scope within the bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli collection-manage  -c localhost:8091 \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--bucket $$COUCHBASE_BUCKET \
		--create-scope sample

.PHONY: movies/collection/create
movies/collection/create: ##@movies Create collection within scope
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli collection-manage  -c localhost:8091 \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--bucket $$COUCHBASE_BUCKET \
		--create-collection sample.movies

.PHONY: movies/index/create
movies/index/create: ##@movies Create indexes
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v http://localhost:8093/query/service \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d 'statement=CREATE PRIMARY INDEX `#primary` ON `playground`.`sample`.`movies`'

	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v http://localhost:8093/query/service \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d 'statement=CREATE INDEX idx_movies_genres ON playground.sample.movies(DISTINCT ARRAY v FOR v IN genres END)'

.PHONY: movies/import
movies/import: ##@movies Import movies into the playground bucket
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
		bash -c "curl https://raw.githubusercontent.com/prust/wikipedia-movie-data/master/movies.json  > /tmp/movies.json"
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	/opt/couchbase/bin/cbimport json -c couchbase://127.0.0.1 \
		-u $$COUCHBASE_USERNAME -p $$COUCHBASE_PASSWORD \
		--scope-collection-exp sample.movies \
		-b $$COUCHBASE_BUCKET -d file:///tmp/movies.json -f list -g \#UUID\#

.PHONY: movies/query
movies/query: ##@movies Run a query to filter out commedies
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v http://localhost:8093/query/service \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d "statement=SELECT * FROM playground.sample.movies AS movies WHERE ANY v IN genres SATISFIES v = 'Comedy' END LIMIT 10"