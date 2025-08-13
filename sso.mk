### SSO

OIDC_NODE?=oidc
SSO_USER?=admin
SSO_PWD?=password
SSO_ENDPOINT?=http://localhost:8080
SSO_REALM?=cb
SSO_CLIENT?=test-client
SSO_CERT_PATH=/opt/keycloak/data/tls
SSO_CERT?=tls.pem
SSO_KEY?=tls.key
SSO_TLS_MOUNT?=$(MFILECWD)/../etc/tls
SSO_REALM_MOUNT?=$(MFILECWD)/../etc/oidc
SSO_PORT?=8443
SSO_PROXY_HEADERS?=xforwarded
SSO_HOSTNAME?=http://localhost

.PHONY: idp/up
idp/up: ##@idp Start idp
	$(DOCKER) run -it --rm -d \
		--env-file=./.env \
		--network $(ENV)_couchbase \
		--name="$(APP)_$(OIDC_NODE)" \
		--mount type=bind,source=$(SSO_REALM_MOUNT),target=/opt/keycloak/data/import \
		--mount type=bind,source=$(SSO_TLS_MOUNT),target=/opt/keycloak/data/tls \
		-p 8080:8080 -p $(SSO_PORT):$(SSO_PORT) \
  		-e KC_BOOTSTRAP_ADMIN_USERNAME=$(SSO_USER) \
  		-e KC_BOOTSTRAP_ADMIN_PASSWORD=$(SSO_PWD) \
		-e KC_DB=dev-file -e KC_HEALTH_ENABLED=true -e KC_METRICS_ENABLED=true \
		-e KC_PROXY_HEADERS=$(SSO_PROXY_HEADERS) \
		-e KC_HTTPS_CERTIFICATE_KEY_FILE=$(SSO_CERT_PATH)/$(SSO_KEY) \
		-e KC_HTTPS_CERTIFICATE_FILE=$(SSO_CERT_PATH)/$(SSO_CERT) \
		quay.io/keycloak/keycloak:$(OIDC_VERSION) \
		start-dev --import-realm --https-port=$(SSO_PORT) --hostname $(SSO_HOSTNAME) \

.PHONY: idp/debug
idp/debug: ##@idp Start idp in debug mode
	$(DOCKER) run -it --rm \
		--env-file=./.env \
		--entrypoint=/bin/bash \
		--network $(ENV)_couchbase \
		--name="$(APP)_$(OIDC_NODE)" \
		--mount type=bind,source=$(SSO_REALM_MOUNT),target=/opt/keycloak/data/import \
		--mount type=bind,source=$(SSO_TLS_MOUNT),target=/opt/keycloak/data/tls \
		-p 8080:8080 -p $(SSO_PORT):$(SSO_PORT) \
  		-e KC_BOOTSTRAP_ADMIN_USERNAME=$(SSO_USER) \
  		-e KC_BOOTSTRAP_ADMIN_PASSWORD=$(SSO_PWD) \
		-e KC_DB=dev-file -e KC_HEALTH_ENABLED=true -e KC_METRICS_ENABLED=true \
		-e KC_PROXY_HEADERS=$(SSO_PROXY_HEADERS) \
		-e KC_HTTPS_CERTIFICATE_KEY_FILE=$(SSO_CERT_PATH)/$(SSO_KEY) \
		-e KC_HTTPS_CERTIFICATE_FILE=$(SSO_CERT_PATH)/$(SSO_CERT) \
		quay.io/keycloak/keycloak:$(OIDC_VERSION) \

.PHONY: idp/down
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