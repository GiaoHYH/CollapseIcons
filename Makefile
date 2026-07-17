.PHONY: build run clean install

build:
	./scripts/build.sh

run: build
	pkill -x CollapseIcons 2>/dev/null || true
	open build/CollapseIcons.app

install: build
	rm -rf /Applications/CollapseIcons.app
	cp -R build/CollapseIcons.app /Applications/
	@echo "Installed to /Applications/CollapseIcons.app"

clean:
	rm -rf build
