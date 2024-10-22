VAULT_NODE=vault
VAULT_ROOT_TOKEN=password
VAULT_DB_NAME=demo-db
VAULT_USER=vault-root
VAULT_PWD=password
VAULT_LEASE_ID?=
ALLOWED_ROLES=*

.PHONY: vault/up
vault/up: ##@Vault start vault in a container
	@echo "Please note the root token is '$(VAULT_ROOT_TOKEN)', run vault login first"
	$(DOCKER) run --cap-add=IPC_LOCK --name="$(APP)_$(VAULT_NODE)" --rm \
	--network $(ENV)_couchbase \
	-e VAULT_DEV_ROOT_TOKEN_ID=$(VAULT_ROOT_TOKEN) \
	-e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
	-e VAULT_ADDR=http://0.0.0.0:8200 \
	-p 8200:8200 \
	vault server -dev

.PHONY: vault/ssh
vault/ssh: ##@Vault Exec into the vault container 
	@echo "Please note the root token is '$(VAULT_ROOT_TOKEN)', run vault login first"
	@$(DOCKER) exec -it "$(APP)_$(VAULT_NODE)" /bin/ash

.PHONY: vault/plugin/list
vault/plugin/list: ##@Vault List vault plugins	
	$(DOCKER) exec -it "$(APP)_$(VAULT_NODE)" /bin/ash -c "vault login $(VAULT_ROOT_TOKEN) && vault plugin list"

# Prior to initializing the plugin, ensure that you have created an administration account. 
# Vault will use the user specified here to create/update/revoke database credentials. 
# That user must have the appropriate permissions to perform actions upon other database users.

.PHONY: vault/cb/create-user
vault/cb/create-user: ##@Vault Create User
	$(DOCKER) exec -it $(APP)_$(MAIN_NODE) \
	./bin/couchbase-cli user-manage \
		--cluster $(API_ENDPOINT) \
		--username $$COUCHBASE_USERNAME \
		--password $$COUCHBASE_PASSWORD \
		--set \
		--rbac-username $$VAULT_USER \
		--rbac-password $$VAULT_PWD \
		--roles admin \
		--auth-domain local

.PHONY: vault/create-db
vault/create-db: ##@Vault Enable database secret engine
	$(DOCKER) exec -it "$(APP)_$(VAULT_NODE)" /bin/ash -c "vault login $(VAULT_ROOT_TOKEN) && vault secrets enable database"


.PHONY: vault/plugin-init
vault/plugin-init: ##@Vault Initialize couchbase vault plugin
	$(DOCKER) exec -it "$(APP)_$(VAULT_NODE)" /bin/ash -c 'PEM=$$(wget -O - http://$(COUCHBASE_USERNAME):$(COUCHBASE_PASSWORD)@$(APP)_$(MAIN_NODE):8091/pools/default/certificate|base64 -w0) && vault login $(VAULT_ROOT_TOKEN) && vault write database/config/$(VAULT_DB_NAME) plugin_name="couchbase-database-plugin" hosts="couchbases://$(APP)_$(MAIN_NODE)" username=$(VAULT_USER) password=$(VAULT_PWD) tls=true insecure_tls=true base64pem=$${PEM} allowed_roles=$(ALLOWED_ROLES)'

# You should consider rotating the admin password. Note that if you do, the new password will never be made available
# through Vault, so you should create a vault-specific database admin user for this.

.PHONY: vault/rotate-admin
vault/rotate-admin: ##@Vault Rotate Couchbase password we used to setup 
	$(DOCKER) exec -it "$(APP)_$(VAULT_NODE)" /bin/ash -c "vault login $(VAULT_ROOT_TOKEN) && vault write -f database/rotate-root/$(VAULT_DB_NAME)"

.PHONY: vault/role/create-dynamic
vault/role/create-dynamic: ##@Vault Create a dynamic role
	$(DOCKER) exec -it "$(APP)_$(VAULT_NODE)" /bin/ash -c 'vault login $(VAULT_ROOT_TOKEN) && vault write database/roles/couchbase-ro-admin-role db_name=$(VAULT_DB_NAME) default_ttl="5m" max_ttl="1h" creation_statements='\''{"roles":[{"role":"ro_admin"}]}'\'''

.PHONY: vault/role/read-dynamic
vault/role/read-dynamic: ##@Vault Read a dynamic role
	$(DOCKER) exec -it "$(APP)_$(VAULT_NODE)" /bin/ash -c "vault login $(VAULT_ROOT_TOKEN) && vault read database/roles/couchbase-ro-admin-role" 

.PHONY: vault/secret/create-dynamic
vault/secret/create-dynamic: ##@Vault Create a dynamic secret
	$(DOCKER) exec -it "$(APP)_$(VAULT_NODE)" /bin/ash -c "vault login $(VAULT_ROOT_TOKEN) && vault read database/creds/couchbase-ro-admin-role" 

.PHONY: vault/secret/extend-dynamic
vault/secret/extend-dynamic: ##@Vault Extend a dynamic role VAULT_LEASE_ID
	$(DOCKER) exec -it "$(APP)_$(VAULT_NODE)" /bin/ash -c "vault login $(VAULT_ROOT_TOKEN) && vault lease renew -increment=16h database/creds/couchbase-ro-admin-role/$(VAULT_LEASE_ID)" 


.PHONY: vault/secret/list
vault/secret/list: ##@Vault List database roles
	$(DOCKER) exec -it "$(APP)_$(VAULT_NODE)" /bin/ash -c "vault login $(VAULT_ROOT_TOKEN) && vault list database/roles" 
