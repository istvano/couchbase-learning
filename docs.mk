### API

SPEC_URL?=openapi.yaml

.PHONY: openapi/redoc
openapi/redoc: ##@openapi redoc
	$(DOCKER) run -it --rm -p 8080:80 \
  		-v $(ETC)/openapi.generated.yaml:/usr/share/nginx/html/openapi.yaml \
		-e SPEC_URL=$(SPEC_URL) \
		redocly/redoc