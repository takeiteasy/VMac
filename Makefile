.PHONY: clean build all run xcode

all: clean build run

build:
	@swift build
	@codesign --entitlements vmac.entitlements --force -s - .build/debug/vmac
	@codesign --entitlements vmac.entitlements --force -s - .build/arm64-apple-macosx/debug/vmac

run:
	@swift run --skip-build vmac $(ARGS)

clean:
	@swift package clean

veryclean:
	@rm -rf .build

xcode:
	@sh xcodesign.sh
