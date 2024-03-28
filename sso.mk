### SSO

OIDC_NODE?=oidc

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