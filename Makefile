THEOS ?= $(if $(THEOS_HOME),$(THEOS_HOME),$(HOME)/theos)
CONFIG ?= release
PYTHON ?= python3
MITIGATION_CATALOG ?= config/mitigations.json
POLICY_VALUE_CATALOG ?= config/policy-values.json
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
ARTIFACT_DIR ?= dist
FINAL_DYLIB ?= $(ARTIFACT_DIR)/runtime.dylib

export LH_ENABLE_VARIABILITY ?= 1
export LH_ENABLE_DIAGNOSTICS ?= 0

.PHONY: all build clean generate sign copy-artifact audit verify summary strings symbols swift-absence debug-log-absence seed-check state-check policy-check

all: copy-artifact

build: generate
	$(MAKE) -C packages/tweak THEOS="$(THEOS)" DEBUG=$(THEOS_DEBUG) FINALPACKAGE=$(THEOS_FINALPACKAGE)

generate:
	$(PYTHON) scripts/build/generate-mitigation-build.py --catalog "$(MITIGATION_CATALOG)" --values "$(POLICY_VALUE_CATALOG)" --selection "$(BUILD_SELECTION)"

clean:
	$(MAKE) -C packages/tweak THEOS="$(THEOS)" clean
	rm -rf "$(ARTIFACT_DIR)"

sign: build
	scripts/build/sign-dylib.sh "$(TARGET_DYLIB)"

copy-artifact: sign
	mkdir -p "$(ARTIFACT_DIR)"
	cp -f "$(TARGET_DYLIB)" "$(FINAL_DYLIB)"

audit: copy-artifact verify

verify: seed-check state-check policy-check summary strings symbols swift-absence debug-log-absence

summary:
	scripts/verify/macho-summary.sh "$(FINAL_DYLIB)"

strings:
	scripts/verify/string-scan.sh "$(FINAL_DYLIB)"

symbols:
	scripts/verify/exported-symbol-scan.sh "$(FINAL_DYLIB)"

swift-absence:
	scripts/verify/swift-runtime-absence.sh "$(FINAL_DYLIB)"

debug-log-absence:
	scripts/verify/debug-log-absence.sh "$(FINAL_DYLIB)"

seed-check:
	scripts/verify/seed-derivation-check.sh

state-check: generate
	scripts/verify/state-provider-check.sh

policy-check: generate
	scripts/verify/policy-query-check.sh
