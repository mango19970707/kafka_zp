TARGET_VER = 3.7.1
DOCKER_IMAGE_NAME = docker.servicewall.cn/infra/kafka:$(TARGET_VER)
ORIGIN_IMG_TAG = 11-jre-slim
TAR_NAME_PREFIX = kafka-$(TARGET_VER)
XZ_THREAD = 3

all:
.PHONY: makesure_docker_builder docker_push

build:

push: build

makesure_docker_builder:
ifeq ($(shell docker buildx inspect sw_builder 2>/dev/null || echo $$?),1)
	docker buildx create --name sw_builder --platform linux/amd64,linux/arm64 --use
else
	@echo "found docker builder named 'sw_builder'"
	docker buildx use sw_builder
endif

docker_push: makesure_docker_builder
	docker buildx build --pull --platform linux/amd64,linux/arm64 --push \
		-t $(DOCKER_IMAGE_NAME) --build-arg ORIGIN_IMG_TAG=$(ORIGIN_IMG_TAG) .

docker_tar_amd64: makesure_docker_builder
	set -e; set -o pipefail; \
	docker buildx build --pull --platform linux/amd64 -o type=docker,dest=- \
		-t $(DOCKER_IMAGE_NAME) --build-arg ORIGIN_IMG_TAG=$(ORIGIN_IMG_TAG) . | xz -T  $(XZ_THREAD) > kafka-$(TARGET_VER)_amd64.docker.txz
docker_tar_arm64: makesure_docker_builder
	set -e; set -o pipefail; \
	docker buildx build --pull --platform linux/arm64 -o type=docker,dest=- \
		-t $(DOCKER_IMAGE_NAME) --build-arg ORIGIN_IMG_TAG=$(ORIGIN_IMG_TAG) . | xz -T  $(XZ_THREAD) > kafka-$(TARGET_VER)_arm64.docker.txz

sync_origin: makesure_docker_builder
	docker buildx build --platform linux/amd64,linux/arm64 --push \
		-f origin.Dockerfile \
		-t docker.servicewall.cn/origin/openjdk:$(ORIGIN_IMG_TAG) --build-arg ORIGIN_IMG_TAG=$(ORIGIN_IMG_TAG) .

gen_upgrade_tarball: clean docker_tar_amd64 docker_tar_arm64
	@set -e; \
		export SW_META_VERSION=1.0; \
		export SW_SERVICE_NAME=kafka; \
		export SW_DOCKER_IMAGE_NAME=$(DOCKER_IMAGE_NAME); \
		export SW_META_PLATFORM=amd64; \
		export SW_DOCKER_TAR_FILE=$(TAR_NAME_PREFIX)_$${SW_META_PLATFORM}.docker.txz; \
		export SW_UPGRADE_FILENAME=$${SW_SERVICE_NAME}_upgrade-$(TARGET_VER)_$${SW_META_PLATFORM}.tar; \
		curl -sLf https://res-download.s3.cn-northwest-1.amazonaws.com.cn/antibot/upgrade/scripts/gen_s3_upgrade_tarball.sh | bash; \
		export SW_META_PLATFORM=arm64; \
		export SW_DOCKER_TAR_FILE=$(TAR_NAME_PREFIX)_$${SW_META_PLATFORM}.docker.txz;\
		export SW_UPGRADE_FILENAME=$${SW_SERVICE_NAME}_upgrade-$(TARGET_VER)_$${SW_META_PLATFORM}.tar; \
		curl -sLf https://res-download.s3.cn-northwest-1.amazonaws.com.cn/antibot/upgrade/scripts/gen_s3_upgrade_tarball.sh | bash ;

clean:
	rm -rf *.docker.txz
	rm -rf *.tar

upgrade_tar_amd64: docker_tar_amd64
	@set -e; \
		export SKIP_UPLOAD=true; \
		export SW_META_VERSION=1.0; \
		export SW_SERVICE_NAME=kafka; \
		export SW_DOCKER_IMAGE_NAME=$(DOCKER_IMAGE_NAME); \
		export SW_META_PLATFORM=amd64; \
		export SW_DOCKER_TAR_FILE=$(TAR_NAME_PREFIX)_$${SW_META_PLATFORM}.docker.txz; \
		export SW_UPGRADE_FILENAME=$${SW_SERVICE_NAME}_upgrade-$(shell date +'%Y%m')_$${SW_META_PLATFORM}.tar; \
		curl -sLf https://res-download.s3.cn-northwest-1.amazonaws.com.cn/antibot/upgrade/scripts/gen_s3_upgrade_tarball.sh | bash

upgrade_tar_arm64: docker_tar_arm64
	@set -e; \
		export SKIP_UPLOAD=true; \
		export SW_META_VERSION=1.0; \
		export SW_SERVICE_NAME=kafka; \
		export SW_DOCKER_IMAGE_NAME=$(DOCKER_IMAGE_NAME); \
		export SW_META_PLATFORM=arm64; \
		export SW_DOCKER_TAR_FILE=$(TAR_NAME_PREFIX)_$${SW_META_PLATFORM}.docker.txz; \
		export SW_UPGRADE_FILENAME=$${SW_SERVICE_NAME}_upgrade-$(shell date +'%Y%m')_$${SW_META_PLATFORM}.tar; \
		curl -sLf https://res-download.s3.cn-northwest-1.amazonaws.com.cn/antibot/upgrade/scripts/gen_s3_upgrade_tarball.sh | bash
