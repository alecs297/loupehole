THEOS ?= $(if $(THEOS_HOME),$(THEOS_HOME),$(HOME)/theos)
CONFIG ?= release
PYTHON ?= python3
MITIGATION_CATALOG ?= config/mitigations.json
BUILD_SELECTION ?= config/build.default.json

ifeq ($(CONFIG),debug)
THEOS_DEBUG := 1
THEOS_FINALPACKAGE := 0
THEOS_OBJ_CONFIG := debug
else
THEOS_DEBUG := 0
THEOS_FINALPACKAGE := 1
THEOS_OBJ_CONFIG := release
endif

TARGET_DYLIB ?= packages/tweak/.theos/obj/runtime.dylib

export LH_ENABLE_VARIABILITY ?= 1
export LH_ENABLE_DIAGNOSTICS ?= 0

.PHONY: all clean generate sign audit verify summary strings symbols swift-absence debug-log-absence seed-check

all: generate
	$(MAKE) -C packages/tweak THEOS="$(THEOS)" DEBUG=$(THEOS_DEBUG) FINALPACKAGE=$(THEOS_FINALPACKAGE)

generate:
	$(PYTHON) scripts/build/generate-mitigation-build.py --catalog "$(MITIGATION_CATALOG)" --selection "$(BUILD_SELECTION)"

clean:
	$(MAKE) -C packages/tweak THEOS="$(THEOS)" clean

sign: all
	scripts/build/sign-dylib.sh "$(TARGET_DYLIB)"

audit: sign verify

verify: summary strings symbols swift-absence debug-log-absence

summary:
	scripts/verify/macho-summary.sh "$(TARGET_DYLIB)"

strings:
	scripts/verify/string-scan.sh "$(TARGET_DYLIB)"

symbols:
	scripts/verify/exported-symbol-scan.sh "$(TARGET_DYLIB)"

swift-absence:
	scripts/verify/swift-runtime-absence.sh "$(TARGET_DYLIB)"

debug-log-absence:
	scripts/verify/debug-log-absence.sh "$(TARGET_DYLIB)"

seed-check:
	scripts/verify/seed-derivation-check.sh
