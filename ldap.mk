LDAP_NODE=openldap
LDAPGUI_NODE=phpldap

.PHONY: ldap/up
ldap/up: ##@Ldap start openldap in a container
	$(DOCKER) run --name="$(APP)_$(LDAP_NODE)" --rm \
	--network $(ENV)_couchbase \
	--hostname openldap \
	-e LDAP_ORGANISATION="My Org" \
	-e LDAP_DOMAIN="example.local" \
	-e LDAP_ADMIN_PASSWORD="password" \
    -e LDAP_CONFIG_PASSWORD="password" \
    -e LDAP_READONLY_USER_USERNAME="readonly" \
    -e LDAP_READONLY_USER_PASSWORD="readonly" \
	-e LDAP_SEED_INTERNAL_LDIF_PATH="/home/ldif" \
	-e KEEP_EXISTING_CONFIG=false \
	-p 389:389 -p 636:636 \
	-v "$$(pwd)/../etc/ldap/example.ldif:/home/ldif/example.ldif:ro" \
	osixia/openldap:1.5.0 --copy-service -l debug

.PHONY: ldap/gui
ldap/gui: ##@Ldap start ldap gui
	$(DOCKER) run --name="$(APP)_$(LDAPGUI_NODE)" --rm \
	--network $(ENV)_couchbase \
	--hostname openldapgui \
  	-e PHPLDAPADMIN_LDAP_HOSTS=openldap \
  	-e PHPLDAPADMIN_HTTPS=false \
	-p 8080:80 \
	osixia/phpldapadmin:0.9.0

.PHONY: ldap/ssh
ldap/ssh: ##@Ldap Exec into the ldap container 
	@$(DOCKER) exec -it "$(APP)_$(LDAP_NODE)" /bin/ash

# You should login with:
# cn=admin,dc=example,dc=local
# password

# cn=adminUserAlias2,dc=example,dc=local
# password

# uid=readUser,ou=people,dc=example,dc=local
# password

# ou=people,dc=example,dc=local
# ou=groups,dc=example,dc=local
# Each user (e.g., uid=adminUser,ou=people,dc=example,dc=local)
# Each group (e.g., cn=admin,ou=groups,dc=example,dc=local)

# The DN itself is the alias location in the directory, for example:
# dn: uid=adminAlias1,ou=aliases,dc=example,dc=local