### rbac

# see permissions https://github.com/couchbase/ns_server/blob/master/apps/ns_server/src/menelaus_roles.erl#L418

.PHONY: rbac/whoami
rbac/whoami: ##@rest Get whoami
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/whoami \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq

.PHONY: rbac/roles
rbac/roles: ##@rest Get the roles
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/roles \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq	

.PHONY: rbac/permissions
rbac/permissions: ##@rest Get the permissions for current user
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/checkPermissions \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d '$(PERMISSION)' | jq ;

.PHONY: rbac/users
rbac/users: ##@rest Get users
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/users \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq	

.PHONY: rbac/groups
rbac/groups: ##@rest Get the groups
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/groups \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq

.PHONY: rbac/create-user-per-roles
rbac/create-user-per-roles: ##@rest Create a user per role
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

.PHONY: rbac/delete-user-per-roles
rbac/delete-user-per-roles: ##@rest Delete a user for every role
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

.PHONY: rbac/check-perms-all
rbac/check-perms-all: ##@rest Get user permissions for all users
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


.PHONY: rbac/check-perms
rbac/check-perms: ##@rest Check DB_USER permission against list
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/pools/default/checkPermissions \
		-u $(DB_USER):$$COUCHBASE_PASSWORD \
		-d '$(PERMISSION)' | jq

.PHONY: settings/list
settings/list: ##@rest Check settings
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/security/ \
		-u $(DB_USER):$$COUCHBASE_PASSWORD | jq

.PHONY: settings/rbac/disable-http-ui
settings/rbac/disable-http-ui: ##@users Disable UI http access
	$(CURL) $(CURL_OPTS) -X POST $(API_ENDPOINT)/settings/security \
		-u $(DB_USER):$$COUCHBASE_PASSWORD \
		-d disableUIOverHttp=true \
		-d tlsMinVersion=tlsv1.3 | jq

.PHONY: settings/rbac/configure-hashing
settings/rbac/configure-hashing: ##@users Configure hashing to argon2
	$(CURL) $(CURL_OPTS) -X POST $(API_ENDPOINT)/settings/security \
		-u $(DB_USER):$$COUCHBASE_PASSWORD \
		-d scramSha1Enabled=false \
		-d scramSha256Enabled=false \
		-d scramSha512Enabled=false \
		-d passwordHashAlg=argon2id | jq

.PHONY: settings/rbac/backup
settings/rbac/backup: ##@users Backup users
	$(CURL) $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/backup \
		-u $(DB_USER):$$COUCHBASE_PASSWORD | jq

.PHONY: settings/rbac/restore
settings/rbac/restore: ##@users Restore users
	@echo "not documented"

