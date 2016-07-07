PACKAGE = fwknop
ORG = amylum

BUILD_DIR = /tmp/$(PACKAGE)-build
RELEASE_DIR = /tmp/$(PACKAGE)-release
RELEASE_FILE = /tmp/$(PACKAGE).tar.gz

PACKAGE_VERSION = $$(git --git-dir=upstream/.git describe --tags)
PATCH_VERSION = $$(cat version)
VERSION = $(PACKAGE_VERSION)-$(PATCH_VERSION)

PATH_FLAGS = --prefix=/usr --sysconfdir=/etc --localstatedir=/var --sbindir=/usr/bin

LIBPCAP_VERSION = 1.7.4-3
LIBPCAP_URL = https://github.com/amylum/libpcap/releases/download/$(LIBPCAP_VERSION)/libpcap.tar.gz
LIBPCAP_TAR = /tmp/libpcap.tar.gz
LIBPCAP_DIR = /tmp/libpcap
LIBPCAP_PATH = -I$(LIBPCAP_DIR)/usr/include -L$(LIBPCAP_DIR)/usr/lib

GPGME_VERSION = 1.6.0-5
GPGME_URL = https://github.com/amylum/gpgme/releases/download/$(GPGME_VERSION)/gpgme.tar.gz
GPGME_TAR = /tmp/gpgme.tar.gz
GPGME_DIR = /tmp/gpgme
GPGME_PATH = -I$(GPGME_DIR)/usr/include -L$(GPGME_DIR)/usr/lib

LIBGPG-ERROR_VERSION = 1.23-5
LIBGPG-ERROR_URL = https://github.com/amylum/libgpg-error/releases/download/$(LIBGPG-ERROR_VERSION)/libgpg-error.tar.gz
LIBGPG-ERROR_TAR = /tmp/libgpgerror.tar.gz
LIBGPG-ERROR_DIR = /tmp/libgpg-error
LIBGPG-ERROR_PATH = -I$(LIBGPG-ERROR_DIR)/usr/include -L$(LIBGPG-ERROR_DIR)/usr/lib

LIBASSUAN_VERSION = 2.4.2-5
LIBASSUAN_URL = https://github.com/amylum/libassuan/releases/download/$(LIBASSUAN_VERSION)/libassuan.tar.gz
LIBASSUAN_TAR = /tmp/libassuan.tar.gz
LIBASSUAN_DIR = /tmp/libassuan
LIBASSUAN_PATH = -I$(LIBASSUAN_DIR)/usr/include -L$(LIBASSUAN_DIR)/usr/lib

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
	rm -rf $(GPGME_DIR) $(GPGME_TAR)
	mkdir $(GPGME_DIR)
	curl -sLo $(GPGME_TAR) $(GPGME_URL)
	tar -x -C $(GPGME_DIR) -f $(GPGME_TAR)
	rm -rf $(LIBGPG-ERROR_DIR) $(LIBGPG-ERROR_TAR)
	mkdir $(LIBGPG-ERROR_DIR)
	curl -sLo $(LIBGPG-ERROR_TAR) $(LIBGPG-ERROR_URL)
	tar -x -C $(LIBGPG-ERROR_DIR) -f $(LIBGPG-ERROR_TAR)
	rm -rf $(LIBASSUAN_DIR) $(LIBASSUAN_TAR)
	mkdir $(LIBASSUAN_DIR)
	curl -sLo $(LIBASSUAN_TAR) $(LIBASSUAN_URL)
	tar -x -C $(LIBASSUAN_DIR) -f $(LIBASSUAN_TAR)
	find /tmp -name '*.la' -delete

build: submodule deps
	rm -rf $(BUILD_DIR)
	cp -R upstream $(BUILD_DIR)
	cd $(BUILD_DIR) && autoreconf -fiv
	cd $(BUILD_DIR) && CC=musl-gcc CFLAGS='$(LIBPCAP_PATH) $(GPGME_PATH) $(LIBGPG-ERROR_PATH) $(LIBASSUAN_PATH)' ./configure $(PATH_FLAGS)
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
	@sleep 2
	targit -a .github -c -f $(ORG)/$(PACKAGE) $(VERSION) $(RELEASE_FILE)
	@sha512sum $(RELEASE_FILE) | cut -d' ' -f1

local: build push

