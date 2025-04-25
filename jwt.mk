### JWT

DATA_ROLE=data_reader[*]
ADMIN_ROLE=security_admin
GROUP_NAME=jwt_data_admins
JWT?=<token>

.PHONY: jwt/settings/configure
jwt/settings/configure: ##@jwt Configure JWT auth
	$(CURL) -X PUT $(CURL_OPTS) $(API_ENDPOINT)/settings/jwt  \
		-H 'Content-Type: application/json' \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d '{"enabled":true,"issuers":[{"name":"http://localhost:8080/realms/cb","signingAlgorithm":"RS256","audClaim":"aud","audienceHandling":"any","audiences":["test-cliet"],"subClaim":"preferred_username","publicKeySource":"jwks_uri","jwksUri":"http://couchbase_oidc:8080/realms/cb/protocol/openid-connect/certs"}]}' \

.PHONY: jwt/settings/delete
jwt/settings/delete: ##@jwt delete JWT auth settings
	$(CURL) -X DELETE $(CURL_OPTS) $(API_ENDPOINT)/settings/jwt  \
		-H 'Content-Type: application/json' \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD

.PHONY: jwt/settings/status
jwt/settings/status: ##@jwt Show JWT auth settings
	$(CURL) --silent $(CURL_OPTS) $(API_ENDPOINT)/settings/jwt  \
		-H 'Content-Type: application/json' \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD | jq .

.PHONY: jwt/user/create
jwt/user/create: ##@jwt Create users
	$(CURL) -X PUT $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/groups/$(GROUP_NAME)  \
	 	-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d 'roles=$(DATA_ROLE),$(ADMIN_ROLE)' \
		-d 'description=JWT data admins'
	$(CURL) -X PUT $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/users/external/data_reader_user  \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d 'name=Data Reader' \
		-d 'roles=$(DATA_ROLE)'
	$(CURL) -X PUT  $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/users/external/security_admin_user  \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d 'name=Security Admin' \
		-d 'roles=$(ADMIN_ROLE)'
	$(CURL) -X PUT  $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/users/external/combined_user \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d 'name=Combined user' \
		-d 'roles=$(DATA_ROLE),$(ADMIN_ROLE)'
	$(CURL) -X PUT $(CURL_OPTS) $(API_ENDPOINT)/settings/rbac/users/external/group_user \
		-u $$COUCHBASE_USERNAME:$$COUCHBASE_PASSWORD \
		-d 'name=Group user' \
		-d 'groups=$(GROUP_NAME)'

.PHONY: jwt/token/data_reader_user
jwt/token/data_reader_user: ##@jwt create access token for data_reader_user
	$(CURL) -X POST '$(SSO_ENDPOINT)/realms/$(SSO_REALM)/protocol/openid-connect/token' \
	-H 'Content-Type: application/x-www-form-urlencoded' \
	-d 'grant_type=password' \
	-d 'scope=openid' \
	-d 'client_id=$(SSO_CLIENT)' \
	-d 'username=data_reader_user' \
	-d 'password=password' | jq

.PHONY: jwt/token/data_reader_user/raw
jwt/token/data_reader_user/raw: ##@jwt create access token for data_reader_user raw
	$(CURL) --silent -X POST '$(SSO_ENDPOINT)/realms/$(SSO_REALM)/protocol/openid-connect/token' \
	-H 'Content-Type: application/x-www-form-urlencoded' \
	-d 'grant_type=password' \
	-d 'scope=openid' \
	-d 'client_id=$(SSO_CLIENT)' \
	-d 'username=data_reader_user' \
	-d 'password=password' | jq -r '.access_token' | cut -d '.' -f2 | base64 --decode

.PHONY: jwt/token/test
jwt/token/test: ##@jwt test token 
	curl -vvv -H "Authorization: Bearer $(JWT)" http://localhost:8091/pools/default