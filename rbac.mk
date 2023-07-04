### Rest

.PHONY: rest/certs
rest/certs: ##@rest List certs
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/certificates \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq

### rbac

.PHONY: rest/rbac/whoami
rest/rbac/whoami: ##@rest Get whoami
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/whoami \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq

.PHONY: rest/rbac/roles
rest/rbac/roles: ##@rest Get the roles
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/roles \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq	

.PHONY: rest/rbac/permissions
rest/rbac/permissions: ##@rest Get the permissions for current user
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/checkPermissions \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d '$(PERMISSION)' | jq ;

.PHONY: rest/rbac/users
rest/rbac/users: ##@rest Get users
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/users \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq	

.PHONY: rest/rbac/groups
rest/rbac/groups: ##@rest Get the groups
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/groups \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq

.PHONY: rest/rbac/create-user-per-roles
rest/rbac/create-user-per-roles: ##@rest Create a user per role
	@for v in $(ROLES) ; do \
		echo "Creating user: $$v"; \
		ROLE_STR="roles=$$v&password=password"; \
		$(CURL) $(CURL_OPTS) -X PUT $(API_ENDPOINT)/settings/rbac/users/local/$$v \
			-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
			-d $$ROLE_STR; \
	done
	@for v in $(BUCKET_ROLES) ; do \
		echo "Creating user: $$v"; \
		ROLE_STR="roles=$$v[*]&password=password"; \
		$(CURL) $(CURL_OPTS) -X PUT $(API_ENDPOINT)/settings/rbac/users/local/$$v \
			-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
			-d $$ROLE_STR; \
	done
	@echo "Completed..."

.PHONY: rest/rbac/delete-user-per-roles
rest/rbac/delete-user-per-roles: ##@rest Delete a user for every role
	@for v in $(ROLES) ; do \
		echo "Deleting user: $$v"; \
		ROLE_STR="roles=$$v&password=password"; \
		$(CURL) $(CURL_OPTS) -X DELETE $(API_ENDPOINT)/settings/rbac/users/local/$$v \
			-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD; \
	done
	@for v in $(BUCKET_ROLES) ; do \
		echo "Deleting user: $$v"; \
		ROLE_STR="roles=$$v&password=password"; \
		$(CURL) $(CURL_OPTS) -X DELETE $(API_ENDPOINT)/settings/rbac/users/local/$$v \
			-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD; \
	done
	@echo "Completed..."

.PHONY: rest/rbac/check-perms-all
rest/rbac/check-perms-all: ##@rest Get user permissions for all users
	@echo "Cluster roles:"
	@for v in $(ROLES) ; do \
		echo "User: $$v"; \
		$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/checkPermissions \
		-u $$v:$$COUCHBASE_PASSWORD \
		-d '$(PERMISSION)' | jq | grep -E '{|}|true' ;\
	done
	@echo "Bucket roles:"
	@for v in $(BUCKET_ROLES) ; do \
		echo "User: $$v"; \
		$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/checkPermissions \
		-u $$v:$$COUCHBASE_PASSWORD \
		-d '$(PERMISSION)' | jq | grep -E '{|}|true' ;\
	done


.PHONY: rest/rbac/check-perms
rest/rbac/check-perms: ##@rest Check DB_USER permission against list
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/checkPermissions \
		-u $(DB_USER):$$COUCHBASE_PASSWORD \
		-d '$(PERMISSION)' | jq