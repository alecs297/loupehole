#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#include <string.h>

typedef NSString *(*LHCameraUniqueIDOriginal)(id self, SEL selector);
typedef id (*LHCameraDeviceWithUniqueIDOriginal)(Class self, SEL selector, NSString *uniqueID);

LH_POLICY_SEED(camera_capture_device_unique_id)

static LHCameraUniqueIDOriginal LHCameraUniqueIDOriginalImplementation;
static LHCameraDeviceWithUniqueIDOriginal LHCameraDeviceWithUniqueIDOriginalImplementation;
static LHPolicyEngine *LHCameraUniqueIDPolicy;

static BOOL LHCameraStringEqualsAny(NSString *value, NSArray<NSString *> *candidates) {
    if (![value isKindOfClass:[NSString class]]) {
        return NO;
    }

    for (NSString *candidate in candidates) {
        if ([value isEqualToString:candidate]) {
            return YES;
        }
    }
    return NO;
}

static BOOL LHCameraDeviceIsContinuityCamera(id device) {
    SEL selector = sel_registerName("isContinuityCamera");
    if (device == nil || selector == 0 || ![device respondsToSelector:selector]) {
        return NO;
    }
    return ((BOOL (*)(id, SEL))objc_msgSend)(device, selector);
}

static BOOL LHCameraDeviceHasExternalType(id device) {
    SEL selector = sel_registerName("deviceType");
    if (device == nil || selector == 0 || ![device respondsToSelector:selector]) {
        return NO;
    }

    NSString *deviceType = ((id (*)(id, SEL))objc_msgSend)(device, selector);
    return LHCameraStringEqualsAny(deviceType,
                                   @[
                                       @"AVCaptureDeviceTypeExternal",
                                       @"AVCaptureDeviceTypeExternalUnknown",
                                       @"AVCaptureDeviceTypeContinuityCamera"
                                   ]);
}

static BOOL LHCameraShouldRewriteUniqueIDForDevice(id device) {
    return LHCameraDeviceIsContinuityCamera(device) || LHCameraDeviceHasExternalType(device);
}

static bool LHCameraCopySyntheticID(NSString *realID, char *output, size_t outputLength) {
    if (LHCameraUniqueIDPolicy == 0 ||
        ![realID isKindOfClass:[NSString class]] ||
        output == 0 ||
        outputLength < 33) {
        return false;
    }

    const char *bytes = [realID UTF8String];
    if (bytes == 0 || bytes[0] == '\0') {
        return false;
    }

    uint8_t digest[16] = { 0 };
    if (!LHMitigationDeriveBytes(&LHCameraUniqueIDPolicy->config.buildSeed,
                                 &LHGeneratedPolicySeed_camera_capture_device_unique_id,
                                 &LHCameraUniqueIDPolicy->appContext.scope,
                                 (const uint8_t *)bytes,
                                 strlen(bytes),
                                 digest,
                                 sizeof(digest))) {
        return false;
    }

    static const char digits[] = "0123456789abcdef";
    for (size_t i = 0; i < sizeof(digest); i++) {
        output[i * 2] = digits[(digest[i] >> 4) & 0x0f];
        output[i * 2 + 1] = digits[digest[i] & 0x0f];
    }
    output[32] = '\0';
    return true;
}

static NSString *LHCameraSyntheticIDForRealID(NSString *realID) {
    char synthetic[33] = { 0 };
    if (!LHCameraCopySyntheticID(realID, synthetic, sizeof(synthetic))) {
        return nil;
    }
    return [NSString stringWithUTF8String:synthetic];
}

static NSString *LHCameraRealUniqueIDForDevice(id device) {
    SEL selector = sel_registerName("uniqueID");
    if (device == nil || selector == 0 || LHCameraUniqueIDOriginalImplementation == 0) {
        return nil;
    }
    return LHCameraUniqueIDOriginalImplementation(device, selector);
}

static NSString *LHCameraRealIDForSyntheticID(Class targetClass, NSString *syntheticID) {
    if (targetClass == Nil || ![syntheticID isKindOfClass:[NSString class]]) {
        return nil;
    }

    SEL devicesSelector = sel_registerName("devices");
    if (devicesSelector == 0 || ![targetClass respondsToSelector:devicesSelector]) {
        return nil;
    }

    NSArray *devices = ((NSArray *(*)(Class, SEL))objc_msgSend)(targetClass, devicesSelector);
    if (![devices isKindOfClass:[NSArray class]]) {
        return nil;
    }

    for (id device in devices) {
        if (!LHCameraShouldRewriteUniqueIDForDevice(device)) {
            continue;
        }
        NSString *realID = LHCameraRealUniqueIDForDevice(device);
        NSString *candidate = LHCameraSyntheticIDForRealID(realID);
        if (candidate != nil && [candidate isEqualToString:syntheticID]) {
            return realID;
        }
    }
    return nil;
}

static NSString *LHCameraUniqueIDReplacement(id self, SEL selector) {
    if (LHCameraUniqueIDOriginalImplementation != 0) {
        NSString *realID = LHCameraUniqueIDOriginalImplementation(self, selector);
        if (!LHCameraShouldRewriteUniqueIDForDevice(self)) {
            return realID;
        }
        NSString *syntheticID = LHCameraSyntheticIDForRealID(realID);
        if (syntheticID != nil) {
            return syntheticID;
        }
        return realID;
    }
    return nil;
}

static id LHCameraDeviceWithUniqueIDReplacement(Class self, SEL selector, NSString *uniqueID) {
    if (LHCameraDeviceWithUniqueIDOriginalImplementation == 0) {
        return nil;
    }

    id device = LHCameraDeviceWithUniqueIDOriginalImplementation(self, selector, uniqueID);
    if (device != nil) {
        return device;
    }

    NSString *realID = LHCameraRealIDForSyntheticID(self, uniqueID);
    if (realID != nil) {
        return LHCameraDeviceWithUniqueIDOriginalImplementation(self, selector, realID);
    }
    return nil;
}

bool LHMitigation_camera_unique_id_avcapturedevice_scoped_id_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHCameraUniqueIDPolicy = policy;

    Class targetClass = NSClassFromString(@"AVCaptureDevice");
    if (targetClass == Nil) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_camera_unique_id_avcapturedevice_scoped_id);
    }

    bool installed = false;
    SEL uniqueIDSelector = sel_registerName("uniqueID");
    SEL lookupSelector = sel_registerName("deviceWithUniqueID:");
    if (uniqueIDSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             targetClass,
                                             uniqueIDSelector,
                                             (void *)LHCameraUniqueIDReplacement,
                                             (void **)&LHCameraUniqueIDOriginalImplementation) || installed;
    }
    if (lookupSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             object_getClass(targetClass),
                                             lookupSelector,
                                             (void *)LHCameraDeviceWithUniqueIDReplacement,
                                             (void **)&LHCameraDeviceWithUniqueIDOriginalImplementation) || installed;
    }

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_camera_unique_id_avcapturedevice_scoped_id);
    }
    return true;
}
