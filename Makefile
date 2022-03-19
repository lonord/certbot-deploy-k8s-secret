APP_NAME = "certbot-deploy-k8s-secret"
APP_VERSION = 1.0.0
REGISTRY = "lonord"

.PHONY: all docker-build clean

all: docker-build

docker-build:
	docker buildx build --platform=linux/amd64,linux/arm64 -t $(REGISTRY)/$(APP_NAME) -t $(REGISTRY)/$(APP_NAME):$(APP_VERSION) . --push

clean:
	find . -name "*.DS_Store" -type f -delete
