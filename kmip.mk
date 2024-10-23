KMIP_NODE=kmip
SYM_KEY_NAME=MySymmetricKey
ENC_SAMPLE_DATA_FILE=/tmp/sample.enc
UENC_SAMPLE_DATA_FILE=/tmp/sample.txt

.PHONY: kmip/tls/create
kmip/tls/create: ##@kmip create a tls certificate for KMIP server
	$(DOCKER) run -it --rm \
	--user $(UID):$(UID) \
	-v $(ETC)/tls:/tmp \
	alpine/openssl genrsa -out /tmp/kmip-ca-key.pem 2048
	@echo "CA key for KMIP created..."

	$(DOCKER) run -it --rm \
	-v $(ETC)/tls:/tmp \
	--user $(UID):$(UID) \
	alpine/openssl req -x509 -new -nodes -sha256 -days 3650 \
		-subj "/C=US/ST=California/L=Santa Clara/O=Acme Inc. /OU=IT Department/CN=Acme CA" \
		-key /tmp/kmip-ca-key.pem \
		-out /tmp/kmip-ca-cert.pem
	@echo "CA certificate for KMIP created..."

	$(DOCKER) run -it --rm \
	-v $(ETC)/tls:/tmp \
	--user $(UID):$(UID) \
	alpine/openssl genrsa -out /tmp/kmip-server-key.pem 2048
	@echo "Server key for KMIP created..."

	$(DOCKER) run -it --rm \
	-v $(ETC)/tls:/tmp \
	--user $(UID):$(UID) \
	alpine/openssl req -new \
		-subj "/C=US/ST=California/L=Santa Clara/O=Acme Inc. /OU=IT Department/CN=localhost" \
		-key /tmp/kmip-server-key.pem \
		-out /tmp/kmip-server-csr.pem
	@echo "Server request and key for KMIP created..."

	$(DOCKER) run -it --rm \
	-v $(ETC)/tls:/tmp \
	--user $(UID):$(UID) \
	alpine/openssl x509 -req -days 1825 -sha256 \
		-in /tmp/kmip-server-csr.pem \
		-out /tmp/kmip-server-cert.pem \
		-CA /tmp/kmip-ca-cert.pem \
		-CAkey /tmp/kmip-ca-key.pem
	@echo "Server certificate for KMIP created..."

	$(DOCKER) run -it --rm \
	-v $(ETC)/tls:/tmp \
	--user $(UID):$(UID) \
	alpine/openssl pkcs12 -export \
		-inkey /tmp/kmip-server-key.pem \
		-in /tmp/kmip-server-cert.pem \
		-certfile /tmp/kmip-ca-cert.pem \
		-name "kmip-server" \
		-password pass:password \
		-out /tmp/kmip-server.p12
	@echo "Server certificate in p12 format for KMIP created..."

	$(DOCKER) run -it --rm \
	-v $(ETC)/tls:/tmp \
	--user $(UID):$(UID) \
	alpine/openssl genrsa -out /tmp/kmip-client-key.pem 2048
	@echo "Client key for KMIP created..."

	$(DOCKER) run -it --rm \
	-v $(ETC)/tls:/tmp \
	--user $(UID):$(UID) \
	alpine/openssl req -new \
		-subj "/C=US/ST=California/L=Santa Clara/O=Acme Inc. /OU=IT Department/CN=admin" \
		-key /tmp/kmip-client-key.pem \
		-out /tmp/kmip-client-csr.pem
	@echo "Server request and key for KMIP created..."

	$(DOCKER) run -it --rm \
	-v $(ETC)/tls:/tmp \
	--user $(UID):$(UID) \
	alpine/openssl x509 -req -days 1825 -sha256 \
		-in /tmp/kmip-client-csr.pem \
		-out /tmp/kmip-client-cert.pem \
		-CA /tmp/kmip-ca-cert.pem \
		-CAkey /tmp/kmip-ca-key.pem
	@echo "Client certificate for KMIP created..."

	rm -rf $(ETC)/tls/kmip-server-cert.pem $(ETC)/tls/kmip-server-csr.pem \
		$(ETC)/tls/kmip-server-key.pem $(ETC)/tls/kmip-client-csr.pem

.PHONY: kmip/up
kmip/up: ##@kmip start kmip in a container
	@echo "Please note"
	$(DOCKER) run --cap-add=IPC_LOCK --name="$(APP)_$(KMIP_NODE)" --rm \
	--network $(ENV)_couchbase \
	-v $(ETC)/tls/kmip-server.p12:/root/cosmian-kms/kmip-server.p12 \
	-v $(ETC)/tls/kmip-ca-cert.pem:/root/cosmian-kms/kmip-ca-cert.pem \
	-p 9998:9998 \
	ghcr.io/cosmian/kms:4.18.0 \
	--https-p12-file=/root/cosmian-kms/kmip-server.p12 \
	--https-p12-password=password \
	--authority-cert-file /root/cosmian-kms/kmip-ca-cert.pem

.PHONY: kmip/ssh
kmip/ssh: ##@kmip Exec into the kmip container 
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" /bin/sh

.PHONY: kmip/ver
kmip/ver: ##@kmip Get KMIP software version
	@$(CURL) --cert $(ETC)/tls/kmip-client-cert.pem \
		--key $(ETC)/tls/kmip-client-key.pem \
		--cacert $(ETC)/tls/kmip-ca-cert.pem https://localhost:9998/version

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

.PHONY: kmip/key/getinfo
kmip/key/getinfo: ##@kmip Get attributes symetric key
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" ckms get-attributes -t $(SYM_KEY_NAME)


.PHONY: kmip/key/rekey
kmip/key/rekey: ##@kmip Rekey symetric key
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" ckms sym keys re-key -t $(SYM_KEY_NAME)
