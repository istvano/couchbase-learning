KMIP_NODE=kmip
SYM_KEY_NAME=MySymmetricKey
ENC_SAMPLE_DATA_FILE=/tmp/sample.enc
UENC_SAMPLE_DATA_FILE=/tmp/sample.txt

KMIP_IMAGE=kmip-test

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
	@echo "Client request and key for KMIP created..."

	$(DOCKER) run -it --rm \
	-v $(ETC)/tls:/tmp \
	--user $(UID):$(UID) \
	alpine/openssl x509 -req -days 1825 -sha256 \
		-in /tmp/kmip-client-csr.pem \
		-out /tmp/kmip-client-cert.pem \
		-CA /tmp/kmip-ca-cert.pem \
		-CAkey /tmp/kmip-ca-key.pem \
		-CAcreateserial \
		-extfile /tmp/client_cert_ext.cnf -extensions v3_req
	@echo "Client certificate for KMIP created..."

	$(DOCKER) run -it --rm \
	-v $(ETC)/tls:/tmp \
	--user $(UID):$(UID) \
	alpine/openssl pkcs12 -export \
		-inkey /tmp/kmip-client-key.pem \
		-in /tmp/kmip-client-cert.pem \
		-certfile /tmp/kmip-ca-cert.pem \
		-name "kmip-client" \
		-password pass:password \
		-out /tmp/kmip-client.p12
	@echo "Client certificate in p12 format for KMIP created..."

#	rm -rf $(ETC)/tls/kmip-server-cert.pem $(ETC)/tls/kmip-server-csr.pem \
#		$(ETC)/tls/kmip-server-key.pem $(ETC)/tls/kmip-client-csr.pem

# RUST_LOG=info,cosmian=info,cosmian_kms_server=debug,actix_web=info,sqlx::query=error,mysql=info"

.PHONY: kmip/pykmip/build
kmip/pykmip/build: ##@kmip Build a pykmip container
	@$(DOCKER) build -t $(KMIP_IMAGE) $(ETC)/code/kmip

.PHONY: kmip/pykmip/run
kmip/pykmip/run: ##@kmip Run a kmip server with pykmip
	$(DOCKER) run --entrypoint=pykmip-server --cap-add=IPC_LOCK --name="$(APP)_$(KMIP_NODE)" --rm \
		--network $(ENV)_couchbase \
		-p 9998:9998 \
		-v $(ETC)/tls:/certs \
		-v $(ETC)/code/kmip/kmip-server.conf:/etc/pykmip/server.conf \
		-v $(ETC)/code/kmip/policy.json:/etc/pykmip/policy/policy.json \
		kmip-test

.PHONY: kmip/pykmip/test
kmip/pykmip/test: ##@kmip Run a test against the KMIP server
	@$(DOCKER) run --rm --network $(ENV)_couchbase \
		-v $(ETC)/tls:/certs \
		-v $(ETC)/code/kmip/test_kmip.py:/app/test_kmip.py \
		-v $(ETC)/code/kmip/pykmip.conf:/etc/pykmip/pykmip.conf \
		-e KMIP_HOST=$(APP)_$(KMIP_NODE) \
		-e KMIP_PORT=9998 \
		-e KMIP_CERT=/certs/kmip-client-cert.pem \
		-e KMIP_KEY=/certs/kmip-client-key.pem \
		-e KMIP_CA=/certs/kmip-ca-cert.pem \
		kmip-test /app/test_kmip.py help

.PHONY: kmip/server/ssh
kmip/ssh: ##@kmip Exec into the kmip container 
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" /bin/sh

.PHONY: kmip/cosmian/run
kmip/cosmian/run: ##@kmip start kmip in a container
	@echo "Please note"
	$(DOCKER) run --cap-add=IPC_LOCK --name="$(APP)_$(KMIP_NODE)" --rm \
	--network $(ENV)_couchbase \
	-e RUST_LOG=DEBUG \
	-v $(ETC)/tmp:/tmp \
	-v $(ETC)/tls/kms.json:/root/cosmian-kms/kms.json \
	-v $(ETC)/tls/kmip-client.p12:/root/cosmian-kms/kmip-client.p12 \
	-v $(ETC)/tls/kmip-server.p12:/root/cosmian-kms/kmip-server.p12 \
	-v $(ETC)/tls/kmip-ca-cert.pem:/root/cosmian-kms/kmip-ca-cert.pem \
	-p 9998:9998 \
	ghcr.io/cosmian/kms:4.19.1 \
	--https-p12-file=/root/cosmian-kms/kmip-server.p12 \
	--https-p12-password=password \
	--authority-cert-file /root/cosmian-kms/kmip-ca-cert.pem

.PHONY: kmip/cosmian/ver
kmip/cosmian/ver: ##@kmip Get KMIP software version
	@$(CURL) --cert $(ETC)/tls/kmip-client-cert.pem \
		--key $(ETC)/tls/kmip-client-key.pem \
		--cacert $(ETC)/tls/kmip-ca-cert.pem https://localhost:9998/version

.PHONY: kmip/cosmian/key/create
kmip/cosmian/key/create: ##@kmip Create symetric key
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" \
	ckms --json --accept-invalid-certs=true -c /root/cosmian-kms/kms.json \
	sym keys create --tag $(SYM_KEY_NAME)

.PHONY: kmip/cosmian/key/encrypt
kmip/cosmian/key/encrypt: ##@kmip Encrypt using symetric key
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" sh -c 'echo "Hello World!" > /tmp/to_encode.txt'
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" ckms --accept-invalid-certs=true -c /root/cosmian-kms/kms.json sym encrypt -t $(SYM_KEY_NAME) /tmp/to_encode.txt -o $(ENC_SAMPLE_DATA_FILE)

.PHONY: kmip/cosmian/key/decrypt
kmip/cosmian/key/decrypt: ##@kmip Decrypt using symetric key
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" ckms --accept-invalid-certs=true -c /root/cosmian-kms/kms.json sym decrypt $(ENC_SAMPLE_DATA_FILE) -t $(SYM_KEY_NAME) -o $(UENC_SAMPLE_DATA_FILE)

.PHONY: kmip/cosmian/key/export
kmip/cosmian/key/export: ##@kmip Export symetric key
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" ckms --accept-invalid-certs=true -c /root/cosmian-kms/kms.json sym keys export -t $(SYM_KEY_NAME) /tmp/exprted.key.json

.PHONY: kmip/cosmian/key/getinfo
kmip/cosmian/key/getinfo: ##@kmip Get attributes symetric key
	@$(DOCKER) exec -it "$(APP)_$(KMIP_NODE)" ckms --accept-invalid-certs=true -c /root/cosmian-kms/kms.json get-attributes -t $(SYM_KEY_NAME)

# .PHONY: kmip/client/key/create
# kmip/client/key/create: ##@kmip Client Create symetric key
# 	$(CURL) -vvv -X POST https://localhost:9998/kmip/2_1 \
#     --cert $(ETC)/tls/kmip-client-cert.pem \
#     --key  $(ETC)/tls/kmip-client-key.pem \
#     --cacert $(ETC)/tls/kmip-ca-cert.pem \
# 	-H "Content-Type: application/json" \
#     -d '{ \
#         "objectType": "SymmetricKey", \
#         "keyFormatType": "RAW", \
#         "cryptographicAlgorithm": "AES", \
#         "cryptographicLength": 256, \
# 		"name": "test" \
#     }'