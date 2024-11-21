### SSO

OIDC_NODE?=oidc
SSO_USER?=admin
SSO_PWD?=password
SSO_ENDPOINT?=http://localhost:8080
SSO_REALM?=cb
SSO_CLIENT?=test-client

.PHONY: oidc/idp/up
oidc/idp/up: ##@oidc Start idp
	$(DOCKER) run -it --rm \
		--env-file=./.env \
		--network $(ENV)_couchbase \
		--name="$(APP)_$(OIDC_NODE)" \
		--mount type=bind,source=$(MFILECWD)/../etc/oidc/cb-realm.json,target=/opt/keycloak/data/import/cb-realm.json \
		--mount type=bind,source=$(MFILECWD)/../etc/tls,target=/opt/keycloak/data/tls \
		-p 8080:8080 -p 8443:8443 \
		-e KEYCLOAK_ADMIN=admin -e KEYCLOAK_ADMIN_PASSWORD=admin \
		-e KC_DB=dev-file -e KC_HEALTH_ENABLED=true -e KC_METRICS_ENABLED=true \
		-e KC_PROXY_HEADERS=xforwarded \
		-e KC_HTTPS_CERTIFICATE_KEY_FILE=/opt/keycloak/data/tls/tls.key \
		-e KC_HTTPS_CERTIFICATE_FILE=/opt/keycloak/data/tls/tls.pem \
		quay.io/keycloak/keycloak:$(OIDC_VERSION) \
		start-dev --import-realm 

.PHONY: oidc/token
oidc/token: ##@oidc Get access token
	$(CURL) -X POST '$(SSO_ENDPOINT)/realms/$(SSO_REALM)/protocol/openid-connect/token' \
	-H 'Content-Type: application/x-www-form-urlencoded' \
	-d 'grant_type=password' \
	-d 'client_id=$(SSO_CLIENT)' \
	-d 'username=$(SSO_USER)' \
	-d 'password=$(SSO_PWD)' | jq

.PHONY: oidc/token/raw
oidc/token/raw: ##@oidc Get access token and decode it
	$(CURL) -X POST '$(SSO_ENDPOINT)/realms/$(SSO_REALM)/protocol/openid-connect/token' \
	-H 'Content-Type: application/x-www-form-urlencoded' \
	-d 'grant_type=password' \
	-d 'client_id=$(SSO_CLIENT)' \
	-d 'username=$(SSO_USER)' \
	-d 'password=$(SSO_PWD)' | jq -r '.access_token' | cut -d '.' -f2 | base64 --decode