export TARGET := iphone:clang:latest:15.0
export ARCHS := arm64
export THEOS_PACKAGE_SCHEME ?= rootless
THEOS_LAYOUT_DIR_NAME ?= generated/package-layout
_THEOS_PLATFORM_DPKG_DEB ?= ../../scripts/build/dpkg-deb-root-owner-group.sh
THEOS_PLATFORM_DEB_COMPRESSION_TYPE ?= xz
LH_STATE_PROVIDER_KIND ?= LHStateProviderKindLocal
LH_EMBED_BUILD_SEED ?= 1

include $(THEOS)/makefiles/common.mk
-include generated/mitigation-files.mk

LH_LOADER_BASENAME ?= runtime
TWEAK_NAME := $(LH_LOADER_BASENAME)
BUNDLE_NAME := LoupeholePreferences

$(LH_LOADER_BASENAME)_FILES := \
	sources/Runtime.mm \
	$(LH_SELECTED_MITIGATION_SOURCES) \
	../../core/generated/LHGeneratedConfig.c \
	../../core/generated/LHGeneratedDerivationLabels.c \
	../../core/generated/LHGeneratedMitigationRegistry.c \
	../../core/generated/LHGeneratedPolicySeeds.c \
	../../core/src/LHAppContext.m \
	../../core/src/LHConfig.c \
	../../core/src/LHConfigProvider.m \
	../../core/src/LHCompatibility.c \
	../../core/src/LHHookBackend.c \
	../../core/src/LHHookBackendTheos.c \
	../../core/src/LHModuleRegistry.c \
	../../core/src/LHPolicyEngine.c \
	../../core/src/LHRuntime.m \
	../../core/src/LHScope.c \
	../../core/src/LHSeed.c \
	../../core/src/LHSeedProvider.m \
	../../core/src/LHStateProvider.m \
	../../core/src/LHTweakValues.c \
	../../core/src/LHValueQuantizer.c

$(LH_LOADER_BASENAME)_CFLAGS += \
	-I../../core/include \
	-I../../core/generated \
	-Isources \
	-fmodules-cache-path=$(CURDIR)/.theos/module-cache \
	-fvisibility=hidden \
	-fdata-sections \
	-ffunction-sections \
	-Wall \
	-Wextra \
	-Werror \
	-DLH_ENABLE_VARIABILITY=$(LH_ENABLE_VARIABILITY) \
	-DLH_ENABLE_DIAGNOSTICS=$(LH_ENABLE_DIAGNOSTICS) \
	-DLH_EMBED_BUILD_SEED=$(LH_EMBED_BUILD_SEED) \
	-DLH_DEFAULT_STATE_PROVIDER_KIND=$(LH_STATE_PROVIDER_KIND)

$(LH_LOADER_BASENAME)_CCFLAGS += $($(LH_LOADER_BASENAME)_CFLAGS) -fvisibility-inlines-hidden
$(LH_LOADER_BASENAME)_OBJCFLAGS += $($(LH_LOADER_BASENAME)_CFLAGS)
$(LH_LOADER_BASENAME)_LDFLAGS += -Wl,-dead_strip -Wl,-x -Wl,-install_name,@rpath/$(LH_LOADER_BASENAME).dylib
$(LH_LOADER_BASENAME)_FRAMEWORKS := Foundation $(LH_SELECTED_FRAMEWORKS)
$(LH_LOADER_BASENAME)_WEAK_FRAMEWORKS := $(LH_SELECTED_WEAK_FRAMEWORKS)
$(LH_LOADER_BASENAME)_LIBRARIES := $(LH_SELECTED_LIBRARIES)

LoupeholePreferences_FILES := \
	prefs/LHPreferenceStore.m \
	prefs/LHPreferenceControllers.m \
	generated/LHGeneratedPreferenceMetadata.c \
	../../core/generated/LHGeneratedConfig.c

LoupeholePreferences_INSTALL_PATH := /Library/PreferenceBundles
LoupeholePreferences_FRAMEWORKS := Foundation UIKit MobileCoreServices
LoupeholePreferences_PRIVATE_FRAMEWORKS :=
LoupeholePreferences_CFLAGS += \
	-I../../core/include \
	-I../../core/generated \
	-Igenerated \
	-fmodules-cache-path=$(CURDIR)/.theos/module-cache \
	-fobjc-arc \
	-Wall \
	-Wextra \
	-Werror \
	-DLH_EMBED_BUILD_SEED=$(LH_EMBED_BUILD_SEED)
LoupeholePreferences_LDFLAGS += -undefined dynamic_lookup
LoupeholePreferences_RESOURCE_DIRS := prefs/Resources

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp prefs/entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/Loupehole.plist$(ECHO_END)

# dpkg-deb --root-owner-group makes fakeroot unnecessary for this deb, and
# avoids host SYSV IPC failures from faked during local package builds.
FAKEROOT = $(abspath ../../scripts/build/fakeroot-root-owner-group.sh)
