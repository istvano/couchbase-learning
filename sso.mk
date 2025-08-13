### SSO

OIDC_NODE?=oidc
SSO_USER?=admin
SSO_PWD?=password
SSO_ENDPOINT?=http://localhost:8080
SSO_REALM?=cb
SSO_CLIENT?=test-client
SSO_CERT?=/opt/keycloak/data/tls/tls.pem
SSO_KEY?=/opt/keycloak/data/tls/tls.key

.PHONY: oidc/idp/up
idp/up: ##@idp Start idp
	$(DOCKER) run -it --rm -d \
		--env-file=./.env \
		--network $(ENV)_couchbase \
		--name="$(APP)_$(OIDC_NODE)" \
		--mount type=bind,source=$(MFILECWD)/../etc/oidc/cb-realm.json,target=/opt/keycloak/data/import/cb-realm.json \
		--mount type=bind,source=$(MFILECWD)/../etc/tls,target=/opt/keycloak/data/tls \
		-p 8080:8080 -p 8443:8443 \
		-e KEYCLOAK_ADMIN=admin -e KEYCLOAK_ADMIN_PASSWORD=admin \
		-e KC_DB=dev-file -e KC_HEALTH_ENABLED=true -e KC_METRICS_ENABLED=true \
		-e KC_PROXY_HEADERS=xforwarded \
		-e KC_HTTPS_CERTIFICATE_KEY_FILE=$(SSO_KEY) \
		-e KC_HTTPS_CERTIFICATE_FILE=$(SSO_CERT) \
		quay.io/keycloak/keycloak:$(OIDC_VERSION) \
		start-dev --import-realm 

.PHONY: oidc/idp/down
idp/down: ##@idp Stop idp
	$(DOCKER) rm -f "$(APP)_$(OIDC_NODE)"

.PHONY: idp/oidc/token
idp/oidc/token: ##@idp Get access token
	$(CURL) -X POST '$(SSO_ENDPOINT)/realms/$(SSO_REALM)/protocol/openid-connect/token' \
	-H 'Content-Type: application/x-www-form-urlencoded' \
	-d 'grant_type=password' \
	-d 'scope=openid' \
	-d 'client_id=$(SSO_CLIENT)' \
	-d 'username=$(SSO_USER)' \
	-d 'password=$(SSO_PWD)' | jq

.PHONY: idp/oidc/token/raw
idp/oidc/token/raw: ##@idp Get access token and decode it
	$(CURL) -s -X POST '$(SSO_ENDPOINT)/realms/$(SSO_REALM)/protocol/openid-connect/token' \
	-H 'Content-Type: application/x-www-form-urlencoded' \
	-d 'grant_type=password' \
	-d 'scope=openid' \
	-d 'client_id=$(SSO_CLIENT)' \
	-d 'username=$(SSO_USER)' \
	-d 'password=$(SSO_PWD)' | jq -r '.access_token' | cut -d '.' -f2 | base64 --decode | jq .

.PHONY: idp/oidc/jwks
idp/oidc/jwks: ##@idp Get the jwks endpoint
	$(CURL) -X GET '$(SSO_ENDPOINT)/realms/$(SSO_REALM)/protocol/openid-connect/certs' | jq .

.PHONY: idp/oidc/config
idp/oidc/config: ##@idp Get the openid config endpoint
	$(CURL) -X GET '$(SSO_ENDPOINT)/realms/$(SSO_REALM)/.well-known/openid-configuration' | jq .

.PHONY: idp/saml
idp/saml: ##@idp Get the saml config endpoint
	$(CURL) -X GET '$(SSO_ENDPOINT)/realms/$(SSO_REALM)/protocol/saml/descriptor'