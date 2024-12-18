.PHONY: build/docker/build
build/docker/build: ##@build Build a bespoke docker container
	$(DOCKER) build -t couchbase-local:$(VERSION) --file $(MFILECWD)/../etc/Dockerfile $(MFILECWD)/../etc


