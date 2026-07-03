# Groove Bound developer targets. Run from the groove-bound/ directory.

LUA ?= luajit

.PHONY: run test lint package clean

run:
	love .

test:
	$(LUA) tests/run.lua

lint:
	luacheck src main.lua conf.lua tests

# Build a distributable .love (a zip of the game folder).
package: clean
	mkdir -p dist
	zip -9 -r dist/groove-bound.love . \
		-x "dist/*" -x "tests/*" -x "Makefile" -x ".luacheckrc" -x "*.md"

clean:
	rm -rf dist
