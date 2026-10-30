.PHONY: run build check

run:
	mkdir -p build
	odin run src -out:build/mylang

build:
	mkdir -p build
	odin build src -out:build/mylang

check:
	odin check src

