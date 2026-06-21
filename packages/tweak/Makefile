export TARGET := iphone:clang:latest:15.0
export ARCHS := arm64
export THEOS_PACKAGE_SCHEME ?= rootless
THEOS_LAYOUT_DIR_NAME ?= generated/package-layout
_THEOS_PLATFORM_DPKG_DEB ?= ../../scripts/build/dpkg-deb-root-owner-group.sh
THEOS_PLATFORM_DEB_COMPRESSION_TYPE ?= xz
LH_STATE_PROVIDER_KIND ?= LHStateProviderKindLocal

include $(THEOS)/makefiles/common.mk
-include generated/mitigation-files.mk

TWEAK_NAME := runtime
BUNDLE_NAME := LoupeholePreferences

runtime_FILES := \
	sources/Runtime.mm \
	$(LH_SELECTED_MITIGATION_SOURCES) \
	$(LH_SELECTED_POLICY_VALUE_SOURCES) \
	../../core/generated/LHGeneratedConfig.c \
	../../core/generated/LHGeneratedDerivationLabels.c \
	../../core/generated/LHGeneratedMitigationRegistry.c \
	../../core/generated/LHGeneratedPolicyValueRegistry.c \
	../../core/src/LHAppContext.m \
	../../core/src/LHConfig.c \
	../../core/src/LHConfigProvider.m \
	../../core/src/LHCompatibility.c \
	../../core/src/LHHookBackend.c \
	../../core/src/LHHookBackendTheos.c \
	../../core/src/LHModuleRegistry.c \
	../../core/src/LHPolicyEngine.c \
	../../core/src/LHProfile.c \
	../../core/src/LHRuntime.m \
	../../core/src/LHScope.c \
	../../core/src/LHSeed.c \
	../../core/src/LHSeedProvider.m \
	../../core/src/LHStateProvider.m \
	../../core/src/LHValueQuantizer.c

runtime_CFLAGS += \
	-I../../core/include \
	-I../../core/generated \
	-fmodules-cache-path=$(CURDIR)/.theos/module-cache \
	-fvisibility=hidden \
	-fdata-sections \
	-ffunction-sections \
	-Wall \
	-Wextra \
	-Werror \
	-DLH_ENABLE_VARIABILITY=$(LH_ENABLE_VARIABILITY) \
	-DLH_ENABLE_DIAGNOSTICS=$(LH_ENABLE_DIAGNOSTICS) \
	-DLH_DEFAULT_STATE_PROVIDER_KIND=$(LH_STATE_PROVIDER_KIND)

runtime_CCFLAGS += $(runtime_CFLAGS) -fvisibility-inlines-hidden
runtime_OBJCFLAGS += $(runtime_CFLAGS)
runtime_LDFLAGS += -Wl,-dead_strip -Wl,-x -Wl,-install_name,@rpath/runtime.dylib
runtime_FRAMEWORKS := Foundation $(LH_SELECTED_FRAMEWORKS)
runtime_WEAK_FRAMEWORKS := $(LH_SELECTED_WEAK_FRAMEWORKS)
runtime_LIBRARIES := $(LH_SELECTED_LIBRARIES)

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
	-Werror
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
