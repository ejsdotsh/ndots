#!/usr/bin/make -f

SHELL := /bin/bash

# https://lithic.tech/blog/2020-05/makefile-dot-env/
ifneq (,$(wildcard ./.env))
	include .env
	export
	ENVFILE_PARAMS = --env-file .env
endif

VERSION := $$(<VERSION)
UID := $$(id -u)
GID := $$(id -g)
NAME := ndots
BUILD_DATE := $$(date +%F)
CURRENT_DIR := $(CURDIR)

##@ General

# adapted from: https://www.padok.fr/en/blog/beautiful-makefile-awk
# The help target prints out all targets with their descriptions organized
# beneath their categories.

.PHONY: help
help: ## display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make <target>\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  %-15s %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: image-clean
image-clean: ## maintenance command to remove intermediate containers
	@docker rmi $$(docker images -f "dangling=true" -q)

.PHONY: test
test: ## shows the value of some variables
	@echo ${VERSION}
	@echo ${CURRENT_DIR}
	@echo ${HOME}
	@echo ${BUILD_DATE}
	@echo $(MAKEFILE_LIST)


##@ Build

.PHONY: nrf
nrf: ## build the Nornir + FastAPI container
	@docker build --force-rm \
		--build-arg BUILD_DATE=${BUILD_DATE} \
		--build-arg BUILD_VERSION=${VERSION} \
		$(ENVFILE_PARAMS) \
		--file nrf/Dockerfile \
		-t "ejsdotsh/nrf:${VERSION}" \
		-t "nrf:latest" nrf

.PHONY: grn
grn: ## build the Gornir + Net/HTTP container
	@docker build --force-rm \
		--build-arg BUILD_DATE=${BUILD_DATE} \
		--build-arg BUILD_VERSION=${VERSION} \
		$(ENVFILE_PARAMS) \
		--file grn/Dockerfile \
		-t "ejsdotsh/grn:${VERSION}" \
		-t "grn:latest" grn


##@ Development

.PHONY: pydev
pydev: nrf ## build and attach to the FastAPI+Nornir container
	@if [ -z $$(docker network ls -q -f name=${NAME}) ]; then \
		docker network create ${NAME}; \
	fi

	@docker run -it --rm --gpus all \
		-h ${NAME} \
		--net=${NAME} \
		--name ${NAME} \
		--mount type=bind,src="${CURRENT_DIR}"/inventories,dst=/srv/nrf/inventories \
		--mount type=bind,src="${CURRENT_DIR}"/conf,dst=/srv/nrf/nr_data \
		--mount type=bind,src="${CURRENT_DIR}"/logs,dst=/srv/nrf/logs \
		--mount type=bind,src="${HOME}"/.ssh/"${ADMIN_USER}",dst=/srv/nrf/.ssh \
		--publish 8080:8080 \
		-w /srv/nrf \
		nrf bash
