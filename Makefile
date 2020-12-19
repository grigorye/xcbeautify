PRODUCT_NAME=xcbeautify
VERSION=$(version)

PREFIX?=/usr/local

CD=cd
CP=$(shell whereis cp) -Rf
GIT=$(shell which git)
HUB=$(shell which hub)
MKDIR=$(shell which mkdir) -p
RM=$(shell whereis rm) -rf
SED=/usr/bin/sed
SWIFT=$(shell which swift)
ZIP=$(shell whereis zip) -r

SWIFT_BUILD_FLAGS = --arch x86_64 --arch arm64 --configuration release \
	--disable-sandbox

TARGET_PLATFORM=universal-apple-macosx
PACKAGE_ZIP="$(PRODUCT_NAME)-$(VERSION)-$(TARGET_PLATFORM).zip"

BINARY_DIRECTORY=$(PREFIX)/bin
BUILD_DIRECTORY=$(shell swift build --show-bin-path $(SWIFT_BUILD_FLAGS))
OUTPUT_EXECUTABLE=$(BUILD_DIRECTORY)/$(PRODUCT_NAME)
INSTALL_EXECUTABLE_PATH=$(BINARY_DIRECTORY)/$(PRODUCT_NAME)

USE_SWIFT_VERSION_4:=$(shell swift -version | grep '.*Swift version 4.*' > /dev/null && echo yes)
ifeq ($(USE_SWIFT_VERSION_4), yes)
# Link Swift stdlib statically
SWIFT_BUILD_FLAGS += --static-swift-stdlib
# Swift 4 uses a different build directory
TARGET_PLATFORM=x86_64-apple-macosx10.10
endif

.PHONY: all
all: build

.PHONY: test
test: clean
	$(SWIFT) test

# Disable sandbox since SwiftPM needs to access to the internet to fetch dependencies
.PHONY: build
build:
	$(SWIFT) build $(SWIFT_BUILD_FLAGS)

.PHONY: install
install: build
	$(MKDIR) $(BINARY_DIRECTORY)
	$(CP) "$(OUTPUT_EXECUTABLE)" "$(BINARY_DIRECTORY)"

.PHONY: package
package: bump-version build
	$(CD) "$(BUILD_DIRECTORY)" && $(ZIP) $(PACKAGE_ZIP) "$(PRODUCT_NAME)"
	$(CP) "$(BUILD_DIRECTORY)/$(PACKAGE_ZIP)" $(PACKAGE_ZIP)

.PHONY: bump-version
bump-version:
	$(SED) -i '' '1s/.*/let version = "$(VERSION)"/' Sources/xcbeautify/Version.swift
	$(SED) -i '' "3s/.*/  s.version        = '$(VERSION)'/" xcbeautify.podspec

.PHONY: release
release: clean package
	$(GIT) commit Sources xcbeautify.podspec -m "Release version $(VERSION)"
	$(GIT) push origin master
	$(GIT) tag $(VERSION)
	$(GIT) push origin $(VERSION)
	$(HUB) release create --message $(VERSION) --attach $(PACKAGE_ZIP) $(VERSION)
	bundle exec pod trunk push --allow-warnings

.PHONY: xcode
xcode:
	$(SWIFT) package generate-xcodeproj

.PHONY: uninstall
uninstall:
	$(RM) "$(BINARY_DIRECTORY)/$(PRODUCT_NAME)"

.PHONY: clean
clean:
	$(SWIFT) package clean
