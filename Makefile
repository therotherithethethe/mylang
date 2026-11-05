.PHONY: run build check debug

run:
	mkdir -p build
	odin run src -out:build/mylang

build:
	mkdir -p build
	odin build src -out:build/mylang

check:
	odin check src

debug:
	mkdir -p build
	odin build src -out:build/mylang -debug
	gf2 build/mylang
