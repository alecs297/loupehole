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

LOADER_BASENAME = $(shell awk -F'"' '/LHGeneratedConfigPackageLoaderBaseName/ { print $$2; found = 1 } END { if (!found) print "runtime" }' core/generated/LHGeneratedConfig.c 2>/dev/null || printf runtime)
TARGET_DYLIB ?= packages/tweak/.theos/obj/$(LOADER_BASENAME).dylib
ARTIFACT_DIR ?= dist
FINAL_DYLIB ?= $(ARTIFACT_DIR)/runtime.dylib
PACKAGE_NAME ?= com.loupehole.runtime
PACKAGE_VERSION ?= 0.1.0
PACKAGE_ARCH ?= iphoneos-arm64
TARGET_DEB ?= packages/tweak/packages/$(PACKAGE_NAME)_$(PACKAGE_VERSION)_$(PACKAGE_ARCH).deb
FINAL_DEB ?= $(ARTIFACT_DIR)/$(PACKAGE_NAME)_$(PACKAGE_VERSION)_$(PACKAGE_ARCH).deb

export LH_ENABLE_VARIABILITY ?= 1
export LH_ENABLE_DIAGNOSTICS ?= 0

.PHONY: all build package package-build copy-package package-verify clean generate sign copy-artifact audit verify summary strings symbols swift-absence debug-log-absence seed-check seed-provider-check state-check policy-check

all: copy-artifact

build: generate
	$(MAKE) -C packages/tweak THEOS="$(THEOS)" DEBUG=$(THEOS_DEBUG) FINALPACKAGE=$(THEOS_FINALPACKAGE)

package: package-verify

package-build: generate
	$(MAKE) -C packages/tweak THEOS="$(THEOS)" DEBUG=0 FINALPACKAGE=1 LH_STATE_PROVIDER_KIND=LHStateProviderKindPackage package

copy-package: package-build
	mkdir -p "$(ARTIFACT_DIR)"
	cp -f "$(TARGET_DEB)" "$(FINAL_DEB)"

package-verify: copy-package
	scripts/verify/package-layout-check.sh "$(FINAL_DEB)"

generate:
	$(PYTHON) scripts/build/generate-mitigation-build.py --catalog "$(MITIGATION_CATALOG)" --values "$(POLICY_VALUE_CATALOG)" --selection "$(BUILD_SELECTION)"

clean:
	$(MAKE) -C packages/tweak THEOS="$(THEOS)" clean
	rm -rf packages/tweak/packages
	rm -rf "$(ARTIFACT_DIR)"

sign: build
	scripts/build/sign-dylib.sh "$(TARGET_DYLIB)"

copy-artifact: sign
	mkdir -p "$(ARTIFACT_DIR)"
	cp -f "$(TARGET_DYLIB)" "$(FINAL_DYLIB)"

audit: copy-artifact verify

verify: seed-check seed-provider-check state-check policy-check summary strings symbols swift-absence debug-log-absence

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

seed-provider-check: generate
	scripts/verify/seed-provider-check.sh

state-check: generate
	scripts/verify/state-provider-check.sh

policy-check: generate
	scripts/verify/policy-query-check.sh
