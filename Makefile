SHELL := /usr/bin/env bash
PREFIX ?= /usr/local

.PHONY: all lint test install uninstall

all: lint test

lint:
	shellcheck bin/gpu-doctor lib/*.sh tests/*.bash

test:
	bash tests/run.bash

install:
	install -d "$(DESTDIR)$(PREFIX)/lib/gpu-doctor" "$(DESTDIR)$(PREFIX)/bin"
	install -m 0644 lib/*.sh "$(DESTDIR)$(PREFIX)/lib/gpu-doctor/"
	install -m 0755 bin/gpu-doctor "$(DESTDIR)$(PREFIX)/bin/gpu-doctor"

uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/gpu-doctor"
	rm -rf "$(DESTDIR)$(PREFIX)/lib/gpu-doctor"

