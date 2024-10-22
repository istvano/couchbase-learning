KMIP_NODE=kmip
SYM_KEY_NAME=MySymmetricKey
ENC_SAMPLE_DATA_FILE=/tmp/sample.enc
UENC_SAMPLE_DATA_FILE=/tmp/sample.txt

.PHONY: kmip/up
kmip/up: ##@kmip start kmip in a container
	@echo "Please note"
	$(DOCKER) run --cap-add=IPC_LOCK --name="$(APP)_$(KMIP_NODE)" --rm \
	--network $(ENV)_couchbase \
	-v $(ETC)/tmp:/tmp \
	-e KMS_DEFAULT_USERNAME=admin \
	-p 9998:9998 \
	ghcr.io/cosmian/kms:4.18.0

.PHONY: kmip/ssh
kmip/ssh: ##@kmip Exec into the kmip container 
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" /bin/sh

.PHONY: kmip/ver
kmip/ver: ##@kmip Get KMIP software version
	@$(CURL) http://localhost:9998/version

.PHONY: kmip/key/create
kmip/key/create: ##@kmip Create symetric key
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" ckms sym keys create --tag $(SYM_KEY_NAME)

.PHONY: kmip/key/encrypt
kmip/key/encrypt: ##@kmip Encrypt using symetric key
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" sh -c 'echo "Hello World!" > /tmp/to_encode.txt'
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" ckms sym encrypt -t $(SYM_KEY_NAME) /tmp/to_encode.txt -o $(ENC_SAMPLE_DATA_FILE)

.PHONY: kmip/key/decrypt
kmip/key/decrypt: ##@kmip Decrypt using symetric key
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" ckms sym decrypt $(ENC_SAMPLE_DATA_FILE) -t $(SYM_KEY_NAME) -o $(UENC_SAMPLE_DATA_FILE)

.PHONY: kmip/key/export
kmip/key/export: ##@kmip Export symetric key
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" ckms sym keys export -t $(SYM_KEY_NAME) /tmp/exprted.key.json


