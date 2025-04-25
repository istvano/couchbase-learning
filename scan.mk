TRIVY=trivy
GRYPE=grype

.PHONY: scan/image/trivy  # --debug
scan/image/trivy: ##@scan Scan image with Trivy
	$(TRIVY) image $(DOCKER_IMAGE):$(VERSION) --timeout 15m

.PHONY: scan/image/grype
scan/image/grype: ##@scan Scan image with grype
	$(GRYPE) $(DOCKER_IMAGE):$(VERSION)

.PHONY: scan/image/blackduck
scan/image/blackduck: ##@scan Scan image with blackduck
	$(DOCKER) run --rm -v /var/run/docker.sock:/var/run/docker.sock \
	-e DETECT_PROJECT_NAME="local-docker-images" \
	-e DETECT_PROJECT_VERSION_NAME="$(VERSION)" \
	-e DETECT_DOCKER_IMAGE="$(DOCKER_IMAGE):$(VERSION)" \
	-v /var/run/docker.sock:/var/run/docker.sock \
	--network host \
	philipssoftware/blackduck:7 /app/detect.sh --blackduck.url=$(SCAN_SERVER) e --blackduck.api.token=$(SCAN_TOKEN)