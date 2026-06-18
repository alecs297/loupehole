#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"
#include "LHGeneratedPolicyValueRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef BOOL (*LHGetResourceValueOriginal)(NSURL *self, SEL selector, id _Nullable *value, NSURLResourceKey key, NSError **error);
typedef NSDictionary<NSURLResourceKey, id> *(*LHResourceValuesOriginal)(NSURL *self, SEL selector, NSArray<NSURLResourceKey> *keys, NSError **error);

static LHGetResourceValueOriginal LHGetResourceValueOriginalImplementation;
static LHResourceValuesOriginal LHResourceValuesOriginalImplementation;
static LHPolicyEngine *LHVolumeTimePolicy;

static NSDate *LHVolumeCreationDate(void) {
    double timestamp = 0.0;
    LHPolicyValueRequest request = {
        .valueID = LHPolicyValueID_volume_creation_time,
        .expectedKind = LHPolicyValueKindTimeInterval,
        .output = &timestamp,
        .outputLength = sizeof(timestamp)
    };
    if (!LHPolicyEngineCopyValue(LHVolumeTimePolicy, &request, 0)) {
        return nil;
    }
    return [NSDate dateWithTimeIntervalSince1970:timestamp];
}

static BOOL LHGetResourceValueReplacement(NSURL *self, SEL selector, id _Nullable *value, NSURLResourceKey key, NSError **error) {
    if ([key isEqualToString:NSURLVolumeCreationDateKey]) {
        NSDate *date = LHVolumeCreationDate();
        if (date != nil) {
            if (value != nil) {
                *value = date;
            }
            return YES;
        }
    }

    if (LHGetResourceValueOriginalImplementation != 0) {
        return LHGetResourceValueOriginalImplementation(self, selector, value, key, error);
    }

    return NO;
}

static NSDictionary<NSURLResourceKey, id> *LHResourceValuesReplacement(NSURL *self, SEL selector, NSArray<NSURLResourceKey> *keys, NSError **error) {
    BOOL wantsVolumeDate = [keys containsObject:NSURLVolumeCreationDateKey];
    NSDictionary<NSURLResourceKey, id> *original = nil;
    if (LHResourceValuesOriginalImplementation != 0) {
        original = LHResourceValuesOriginalImplementation(self, selector, keys, error);
    }

    if (!wantsVolumeDate) {
        return original;
    }

    NSDate *date = LHVolumeCreationDate();
    if (date == nil) {
        return original;
    }

    NSMutableDictionary<NSURLResourceKey, id> *values = original != nil ? [original mutableCopy] : [NSMutableDictionary dictionary];
    values[NSURLVolumeCreationDateKey] = date;
    return values;
}

bool LHMitigation_storage_volume_creation_time_foundation_synthetic_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHVolumeTimePolicy = policy;

    Class targetClass = NSClassFromString(@"NSURL");
    if (targetClass == Nil) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_storage_volume_creation_time_foundation_synthetic);
    }

    bool installed = false;
    SEL getResourceValueSelector = sel_registerName("getResourceValue:forKey:error:");
    SEL resourceValuesSelector = sel_registerName("resourceValuesForKeys:error:");

    if (getResourceValueSelector != 0) {
        installed = LHHookBackendHookMessage(backend, targetClass, getResourceValueSelector, (void *)LHGetResourceValueReplacement, (void **)&LHGetResourceValueOriginalImplementation) || installed;
    }
    if (resourceValuesSelector != 0) {
        installed = LHHookBackendHookMessage(backend, targetClass, resourceValuesSelector, (void *)LHResourceValuesReplacement, (void **)&LHResourceValuesOriginalImplementation) || installed;
    }

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_storage_volume_creation_time_foundation_synthetic);
    }

    return true;
}
