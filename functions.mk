.PHONY: func/create/location
func/create/location: ##@function Create function location
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/_p/query/query/service \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-H "Content-Type: application/json" \
		-d '{"statement":"CREATE FUNCTION locations(vActivity) { (SELECT id, name, address, city  FROM landmark WHERE activity = vActivity) };","query_context":"default:travel-sample.inventory"}'

.PHONY: func/exec/location
func/exec/location: ##@function Exec function location
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/_p/query/query/service \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-H "Content-Type: application/json" \
		-d '{"statement":"SELECT l.name, l.city FROM locations(\"eat\") AS l WHERE l.city = \"Gillingham\";","pretty":true,"query_context":"default:travel-sample.inventory"} '

.PHONY: func/create/celsius
func/create/celsius: ##@function Create function celsius
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/_p/query/query/service \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-H "Content-Type: application/json" \
		-d '{"statement":"CREATE FUNCTION default:celsius(...) { ((args[0] - 32) * 5/9) };"}'

.PHONY: func/exec/celsius
func/exec/celsius: ##@function Execute celsius
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/_p/query/query/service \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d 'statement=EXECUTE FUNCTION default:celsius(100)'

.PHONY: lib/create/businessdays
lib/create/businessdays: ##@function Create lib businessdays
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/_p/query/evaluator/v1/libraries/my-library\?bucket=travel-sample\&scope=inventory \
		-H 'Content-Type: application/json' \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		--data-raw $$'function getBusinessDays(startDate, endDate) {let count = 0;\n    const curDate = new Date(new Date(startDate).getTime());\n    while (curDate <= new Date(endDate)) {\n        const dayOfWeek = curDate.getDay();\n        if(dayOfWeek !== 0 && dayOfWeek !== 6)\n            count++;\n        curDate.setDate(curDate.getDate() + 1);\n    }\n    return count;\n}'

.PHONY: func/create/businessdays
func/create/businessdays: ##@function Create function businessdays
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/_p/query/query/service \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d 'statement=CREATE FUNCTION default:`travel-sample`.inventory.GetBusinessDays(...) LANGUAGE JAVASCRIPT as "getBusinessDays" AT "travel-sample/inventory/my-library"'

.PHONY: func/exec/businessdays
func/exec/businessdays: ##@function Execute function businessdays
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	$(CURL) $(CURL_OPTS) -v $(API_ENDPOINT)/_p/query/query/service \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d 'statement=EXECUTE FUNCTION default:`travel-sample`.inventory.GetBusinessDays("03/10/2022", "05/10.2022")'
