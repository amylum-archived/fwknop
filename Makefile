PACKAGE = fwknop
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags)
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

PATH_FLAGS = --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin

LIBPCAP_VERSION = 1.7.4-1
LIBPCAP_URL = https://github.com/amylum/libpcap/releases/download/$(LIBPCAP_VERSION)/libpcap.tar.gz
LIBPCAP_TAR = /tmp/libpcap.tar.gz
LIBPCAP_DIR = /tmp/libpcap
LIBPCAP_PATH = -I$(LIBPCAP_DIR)/usr/include -L$(LIBPCAP_DIR)/usr/lib

.PHONY : default submodule deps manual container build version push local

default: submodule container

submodule:
	git submodule update --init

manual: submodule
	./meta/launch /bin/bash || true

container:
	./meta/launch

deps:
	rm -rf $(LIBPCAP_DIR) $(LIBPCAP_TAR)
	mkdir $(LIBPCAP_DIR)
	curl -sLo $(LIBPCAP_TAR) $(LIBPCAP_URL)
	tar -x -C $(LIBPCAP_DIR) -f $(LIBPCAP_TAR)

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	cd $(BUILD_DIR) && autoreconf -fiv
	cd $(BUILD_DIR) && CFLAGS='$(LIBPCAP_PATH)' ./configure $(PATH_FLAGS)
	cd $(BUILD_DIR) && make
	cd $(BUILD_DIR) && make DESTDIR=$(RELEASE_DIR) install
	mkdir -p $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)
	cp upstream/COPYING $(RELEASE_DIR)/usr/share/licenses/$(PACKAGE)/LICENSE
	cd $(RELEASE_DIR) && tar -czvf $(RELEASE_FILE) *

version:
	@echo $$(($(PATCH_VERSION) + 1)) > version

push: version
	git commit -am "$(VERSION)"
	ssh -oStrictHostKeyChecking=no git@github.com &>/dev/null || true
	git tag -f "$(VERSION)"
	git push --tags origin master
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

