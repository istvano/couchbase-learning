.PHONY: tls/test
tls/test: ##@tls Check nist compliance
	$(DOCKER) run --rm -ti  drwetter/testssl.sh $(ENDPOINT)