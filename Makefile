SHELL := /usr/bin/env bash
PREFIX ?= /usr/local

.PHONY: all lint test install uninstall

all: lint test

lint:
	shellcheck bin/gpu-sentry lib/*.sh tests/*.bash

test:
	bash tests/run.bash

install:
	install -d "$(DESTDIR)$(PREFIX)/lib/gpu-sentry" "$(DESTDIR)$(PREFIX)/bin"
	install -m 0644 lib/*.sh "$(DESTDIR)$(PREFIX)/lib/gpu-sentry/"
	install -m 0755 bin/gpu-sentry "$(DESTDIR)$(PREFIX)/bin/gpu-sentry"

uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/gpu-sentry"
	rm -rf "$(DESTDIR)$(PREFIX)/lib/gpu-sentry"

