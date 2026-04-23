SHELL := /bin/bash

SWIFT ?= swift
PRODUCT ?= chrome-cli
BUILD_DIR ?= .build
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
ARGS ?=
VERSION ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo dev)
VERSION_FILE ?= Sources/chrome_cli/Generated/BuildVersion.generated.swift

.DEFAULT_GOAL := help

.PHONY: help version-file build release test run clean install uninstall bin-path

help:
	@echo "chrome-cli Make targets"
	@echo ""
	@echo "  make build       Build debug binary"
	@echo "  make release     Build release binary"
	@echo "  make test        Run test suite"
	@echo "  make run         Run CLI in debug mode (use ARGS='...')"
	@echo "  make clean       Remove SwiftPM build artifacts"
	@echo "  make install     Install release binary to $(BINDIR)"
	@echo "  make uninstall   Remove installed binary from $(BINDIR)"
	@echo "  make bin-path    Print release binary path"
	@echo ""
	@echo "Version defaults to: git describe --tags --always --dirty"

version-file:
	@mkdir -p "$(dir $(VERSION_FILE))"
	@tmp_file="$$(mktemp)"; \
	printf 'enum BuildVersion { static let value = "%s" }\n' "$(VERSION)" > "$$tmp_file"; \
	if [ ! -f "$(VERSION_FILE)" ] || ! cmp -s "$$tmp_file" "$(VERSION_FILE)"; then \
		mv "$$tmp_file" "$(VERSION_FILE)"; \
	else \
		rm -f "$$tmp_file"; \
	fi

build: version-file
	$(SWIFT) build

release: version-file
	$(SWIFT) build -c release

test: version-file
	$(SWIFT) test

run: version-file
	$(SWIFT) run $(PRODUCT) $(ARGS)

clean:
	rm -f "$(VERSION_FILE)"
	$(SWIFT) package clean

install: release
	install -d "$(BINDIR)"
	install -m 755 "$(BUILD_DIR)/release/$(PRODUCT)" "$(BINDIR)/$(PRODUCT)"

uninstall:
	rm -f "$(BINDIR)/$(PRODUCT)"

bin-path:
	@echo "$(BUILD_DIR)/release/$(PRODUCT)"
