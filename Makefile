DOCKER_REPO ?= docker.io/charlie0129/devpods
# e.g. if DOCKER_TAG_PREFIX=xxx-, the image will be "docker.io/charlie0129/devpods:xxx-cuda-12.8.1"
DOCKER_TAG_PREFIX ?=

build:
	mkdir -p build

build/dotfiles: build
	cd build && git clone --depth=1 https://github.com/charlie0129/dotfiles.git

cuda-12.8.1: build/dotfiles
	docker build --progress=plain -f $@.dockerfile -t $(DOCKER_REPO):$(DOCKER_TAG_PREFIX)$@ .
