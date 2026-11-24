.PHONY: all build install run clean uninstall helper

all: build

build:
	@chmod +x Scripts/*.sh
	@./Scripts/build.sh

install: build
	@./Scripts/install.sh

run:
	@open build/AutoLowPower.app

helper:
	@./Scripts/setup_helper.sh

clean:
	@rm -rf build
	@echo "Cleaned build artifacts."

uninstall:
	@./Scripts/uninstall.sh
