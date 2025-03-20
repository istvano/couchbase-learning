TRIVY=trivy
GRYPE=grype

.PHONY: scan/image/trivy  # --debug
scan/image/trivy: ##@scan Scan image with Trivy
	$(TRIVY) image $(DOCKER_IMAGE):$(VERSION) --timeout 15m

.PHONY: scan/image/grype
scan/image/grype: ##@scan Scan image with grype
	$(GRYPE) $(DOCKER_IMAGE):$(VERSION)