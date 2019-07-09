# Build tools
#
# Targets (see each target for more information):
#   build:        assembles the dist folder (builds the site content)
#   devmode:      host the site content in build container in live update
#   build-shell:  terminal access to build container for debugging access
#   image:        builds the docker image
#   clean:        removes build artifacts and image
#

###
### Customize  these variables
###

# The binary to build (just the basename).
NAME := blockchain-ui-build

# Where to push the docker image.
REGISTRY ?= registry.gear.ge.com/blockchain

# This version-strategy uses git tags to set the version string
#VERSION := $(shell git describe --tags --always --dirty)
VERSION := 0.1


###
### These variables should not need tweaking.
###

# Platform specific USER  and proxy crud:
# On linux, run the container with the current uid, so files produced from
# within the container are owned by the current user, rather than root.
#
# On OSX, don't do anything with the container user, and let boot2docker manage
# permissions on the /Users mount that it sets up
DOCKER_USER := $(shell if [ "$$OSTYPE" != "darwin"* ]; then USER_ARG="--user=`id -u`"; fi; echo "$$USER_ARG")
PROXY_ARGS := $(shell if [ "$$http_proxy" != "" ]; then echo "-e http_proxy=$$http_proxy"; fi)
PROXY_ARGS += $(shell if [ "$$https_proxy" != "" ]; then echo " -e https_proxy=$$https_proxy"; fi)
PROXY_ARGS += $(shell if [ "$$no_proxy" != "" ]; then echo " -e no_proxy=$$no_proxy"; fi)

IMAGE := $(REGISTRY)/$(NAME)


# Default target
all: build

${NAME}-builder.created:
	@echo "creating builder image ... "
	@docker build                                                                              \
		-t $(NAME):builder                                                                     \
		-f docker/Dockerfile.build                                                             \
		$$(echo $(PROXY_ARGS) | sed s/-e/--build-arg/g)                                        \
		.
	touch ${NAME}-builder.created

build: ${NAME}-builder.created
	@echo "launching builder container (building ./dist folder) ... "
	@echo $(DOCKER_USER)
	@docker run                                                                                \
		-t                                                                                     \
		$(DOCKER_USER)                                                                         \
		$(PROXY_ARGS)                                                                          \
		-v $$(pwd):/www/$(NAME)                                                                \
		-w /www/$(NAME)                                                                        \
		$(NAME):builder                                                                        \
		/bin/sh -c "                                                                           \
			VERSION=$(VERSION)                                                                 \
			./build/build.sh                                                                   \
		"

devmode: ${NAME}-builder.created
	@echo "launching builder container (hosting in live update) ... "
	@echo $(DOCKER_USER)
	@docker run                                                                                \
		-t                                                                                     \
		$(DOCKER_USER)                                                                         \
		$(PROXY_ARGS)                                                                          \
		-v $$(pwd):/www/$(NAME)                                                                \
		-w /www/$(NAME)                                                                        \
		--network=blockchainAssetControlDemo_net                                               \
		-p 5000:5000                                                                           \
		--name blockchain-ui-build-complete                                                    \
		--link blockchain-reverse-proxy-build-complete:blockchain-reverse-proxy-build-complete \
		$(NAME):builder                                                                        \
		/bin/sh -c "                                                                           \
			VERSION=$(VERSION)                                                                 \
			./build/devmode.sh                                                                 \
		"

build-shell: ${NAME}-builder.created
	@echo "Entering build shell..."
	@echo $(DOCKER_USER)
	@docker run                                                                                \
		-it                                                                                    \
		$(DOCKER_USER)                                                                         \
		$(PROXY_ARGS)                                                                          \
		-v $$(pwd):/www/$(NAME)                                                                \
		-w /www/$(NAME)                                                                        \
		-p 5000:5000                                                                           \
		$(NAME):builder                                                                        \
		/bin/bash

image:
	@echo "packaging runtime image ... "
	@docker build                                                                              \
		-t $(NAME):$(VERSION)                                                                  \
		-f docker/Dockerfile.pkg                                                               \
		$$(echo $(PROXY_ARGS) | sed s/-e/--build-arg/g)                                        \
		.

clean:
	@if [ $(shell docker ps -a | grep $(NAME) | wc -l) != 0 ]; then \
		docker ps -a | grep $(NAME) | awk '{print $$1 }' | xargs docker rm -f; \
	fi
	@if [ $(shell docker images | grep $(NAME) | wc -l) != 0 ]; then \
		docker images | grep $(NAME) | awk '{print $$3}' | xargs docker rmi -f || true; \
	fi
	@if [ -f ${NAME}-builder.created ]; then \
		rm ${NAME}-builder.created; \
	fi
