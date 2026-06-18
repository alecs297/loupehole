export TARGET := iphone:clang:latest:15.0
export ARCHS := arm64
export THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk
-include generated/mitigation-files.mk

TWEAK_NAME := runtime

runtime_FILES := \
	sources/Runtime.mm \
	$(LH_SELECTED_MITIGATION_SOURCES) \
	../../core/generated/LHGeneratedMitigationRegistry.c \
	../../core/src/LHAppContext.m \
	../../core/src/LHCoherenceGraph.c \
	../../core/src/LHCompatibility.c \
	../../core/src/LHHookBackend.c \
	../../core/src/LHHookBackendTheos.c \
	../../core/src/LHModuleRegistry.c \
	../../core/src/LHPolicyEngine.c \
	../../core/src/LHProfile.c \
	../../core/src/LHRuntime.m \
	../../core/src/LHScope.c \
	../../core/src/LHSeed.c \
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
	-DLH_ENABLE_DIAGNOSTICS=$(LH_ENABLE_DIAGNOSTICS)

runtime_CCFLAGS += $(runtime_CFLAGS) -fvisibility-inlines-hidden
runtime_OBJCFLAGS += $(runtime_CFLAGS)
runtime_LDFLAGS += -Wl,-dead_strip -Wl,-x -Wl,-install_name,@rpath/runtime.dylib
runtime_FRAMEWORKS := Foundation $(LH_SELECTED_FRAMEWORKS)
runtime_WEAK_FRAMEWORKS := $(LH_SELECTED_WEAK_FRAMEWORKS)
runtime_LIBRARIES := $(LH_SELECTED_LIBRARIES)

include $(THEOS_MAKE_PATH)/tweak.mk
