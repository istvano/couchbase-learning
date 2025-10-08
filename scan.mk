TRIVY=trivy
GRYPE=grype
SNYK=snyk
TAR_FILE?=../etc/tmp/image-output-snyk.tar
CVE?=CVE-2023-44487

.PHONY: scan/image/trivy  # --debug
scan/image/trivy: ##@scan Scan image with Trivy
	$(TRIVY) image $(DOCKER_IMAGE):$(VERSION) --disable-telemetry --timeout 15m --debug

.PHONY: scan/image/trivy/json  # --debug
scan/image/trivy/json: ##@scan Scan image with Trivy
	$(TRIVY) image $(DOCKER_IMAGE):$(VERSION) --disable-telemetry -f json -o ../etc/scans/trivy-result-for-$(VERSION).json --timeout 15m

.PHONY: scan/image/trivy/sarif  # --debug
scan/image/trivy/sarif: ##@scan Scan image with Trivy sarif
	$(TRIVY) image $(DOCKER_IMAGE):$(VERSION) --disable-telemetry  --scanners vuln,misconfig,license,secret -f sarif -o ../etc/scans/trivy-result-for-$(VERSION).sarif --timeout 15m

.PHONY: scan/image/trivy/spdx  # --debug
scan/image/trivy/spdx: ##@scan Scan image with Trivy sarif
	$(TRIVY) image $(DOCKER_IMAGE):$(VERSION) --disable-telemetry --scanners vuln,misconfig,license,secret --format spdx -o ../etc/scans/trivy-result-for-$(VERSION).sbom --timeout 15m

.PHONY: scan/image/trivy/spdx-json  # --debug
scan/image/trivy/spdx-json: ##@scan Scan image with Trivy sarif
	$(TRIVY) image $(DOCKER_IMAGE):$(VERSION) --disable-telemetry --scanners vuln,misconfig,license,secret --format spdx-json -o ../etc/scans/trivy-result-for-$(VERSION).spdx --timeout 15m

.PHONY: scan/image/grype
scan/image/grype: ##@scan Scan image with grype
	$(GRYPE) $(DOCKER_IMAGE):$(VERSION)

.PHONY: scan/image/grype/explain
scan/image/grype/explain: ##@scan Explain a vuln image with grype
	$(GRYPE) $(DOCKER_IMAGE):$(VERSION) -q -o json | grype explain --id $(CVE)

.PHONY: scan/image/grype/json
scan/image/grype/json: ##@scan Scan image with grype output in json
	$(GRYPE) $(DOCKER_IMAGE):$(VERSION) -o json > ../etc/scans/grype-result-for-$(VERSION).json

.PHONY: scan/image/grype/sarif
scan/image/grype/sarif: ##@scan Scan image with grype output in sarif
	$(GRYPE) $(DOCKER_IMAGE):$(VERSION) -o sarif > ../etc/scans/grype-result-for-$(VERSION).sarif

.PHONY: scan/image/grype/spdx
scan/image/grype/spdx: ##@scan Scan image with grype output in sbom
	$(GRYPE) $(DOCKER_IMAGE):$(VERSION) -o cyclonedx > ../etc/scans/grype-result-for-$(VERSION).sbom

.PHONY: scan/image/grype/spdx-json
scan/image/grype/spdx-json: ##@scan Scan image with grype output in sbom
	$(GRYPE) $(DOCKER_IMAGE):$(VERSION) -o cyclonedx-json > ../etc/scans/grype-result-for-$(VERSION).spdx

.PHONY: scan/image/snyk
scan/image/snyk: ##@scan Scan image with snyk
	@echo "Saving Docker image $(DOCKER_IMAGE):$(VERSION) to $(TAR_FILE)..."	
	@$(DOCKER) save -o $(TAR_FILE) $(DOCKER_IMAGE):$(VERSION)
	@echo "Scanning $(TAR_FILE) with Snyk..."
	@$(SNYK) container test docker-archive:$(TAR_FILE) --json > ../etc/scans/snyk-result-for-$(VERSION).json || true
	@echo "Deleting $(TAR_FILE)..."
	@rm -f $(TAR_FILE)

.PHONY: scan/image/snyk/json
scan/image/snyk/json: ##@scan Scan image with snyk json
	@echo "Saving Docker image $(DOCKER_IMAGE):$(VERSION) to $(TAR_FILE)..."
	@$(DOCKER) save -o $(TAR_FILE) $(DOCKER_IMAGE):$(VERSION)
	@echo "Scanning $(TAR_FILE) with Snyk..."
	@$(SNYK) container test docker-archive:$(TAR_FILE) --json > ../etc/scans/snyk-result-for-$(VERSION).json || true
	@echo "Deleting $(TAR_FILE)..."
	@rm -f $(TAR_FILE)
	@echo "Scan and cleanup complete."

.PHONY: scan/image/snyk/sarif
scan/image/snyk/sarif: ##@scan Scan image with snyk sarif
	@echo "Saving Docker image $(DOCKER_IMAGE):$(VERSION) to $(TAR_FILE)..."
	@$(DOCKER) save -o $(TAR_FILE) $(DOCKER_IMAGE):$(VERSION)
	@echo "Scanning $(TAR_FILE) with Snyk..."
	@$(SNYK) container test docker-archive:$(TAR_FILE) --sarif > ../etc/scans/snyk-result-for-$(VERSION).sarif || true
	@echo "Deleting $(TAR_FILE)..."
	@rm -f $(TAR_FILE)
	@echo "Scan and cleanup complete."

.PHONY: scan/image/blackduck
scan/image/blackduck: ##@scan Scan image with blackduck
	$(DOCKER) run --rm -v /var/run/docker.sock:/var/run/docker.sock \
	-e DETECT_PROJECT_NAME="local-docker-images" \
	-e DETECT_PROJECT_VERSION_NAME="$(VERSION)" \
	-e DETECT_DOCKER_IMAGE="$(DOCKER_IMAGE):$(VERSION)" \
	-v /var/run/docker.sock:/var/run/docker.sock \
	--network host \
	philipssoftware/blackduck:7 /app/detect.sh --blackduck.url=$(SCAN_SERVER) e --blackduck.api.token=$(SCAN_TOKEN)

.PHONY: scan/zap
scan/zap: ##@scan Scan with zap
	$(DOCKER) run -v $$(pwd)/../etc/zap:/zap/wrk/:rw -e ZAP_WEBSWING_OPTS="-host 0.0.0.0 -port 9090" -u zap -p 8080:8080 -p 9090:9090 -i ghcr.io/zaproxy/zaproxy:stable zap-webswing.sh

.PHONY: scan/image/check-updates
scan/image/check-updates: ##@scan Scan image with grype output in sbom
	$(DOCKER) run -u 0 --rm -it --entrypoint bash $(DOCKER_IMAGE):$(VERSION) -c "apt update && apt list --upgradable"
