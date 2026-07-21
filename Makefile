SHELL := /usr/bin/env bash
PREFIX ?= /usr/local

.PHONY: all lint test install uninstall

all: lint test

lint:
	shellcheck bin/rackprobe lib/*.sh tests/*.bash

test:
	bash tests/run.bash

install:
	install -d "$(DESTDIR)$(PREFIX)/lib/rackprobe" "$(DESTDIR)$(PREFIX)/bin"
	install -m 0644 lib/*.sh "$(DESTDIR)$(PREFIX)/lib/rackprobe/"
	install -m 0755 bin/rackprobe "$(DESTDIR)$(PREFIX)/bin/rackprobe"

uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/rackprobe"
	rm -rf "$(DESTDIR)$(PREFIX)/lib/rackprobe"

