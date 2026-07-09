#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef BOOL (*LHStorageGetResourceValueOriginal)(NSURL *self, SEL selector, id _Nullable *value, NSURLResourceKey key, NSError **error);
typedef NSDictionary<NSURLResourceKey, id> *(*LHStorageResourceValuesOriginal)(NSURL *self, SEL selector, NSArray<NSURLResourceKey> *keys, NSError **error);

static LHStorageGetResourceValueOriginal LHStorageCapacityGetResourceValueOriginalImplementation;
static LHStorageResourceValuesOriginal LHStorageCapacityResourceValuesOriginalImplementation;

static BOOL LHStorageCapacityKeyIsCovered(NSURLResourceKey key) {
    return [key isEqualToString:NSURLVolumeAvailableCapacityKey] ||
           [key isEqualToString:NSURLVolumeAvailableCapacityForImportantUsageKey] ||
           [key isEqualToString:NSURLVolumeAvailableCapacityForOpportunisticUsageKey];
}

static uint64_t LHStorageCapacityBucketSize(uint64_t value) {
    static const uint64_t mib = 1024ULL * 1024ULL;
    static const uint64_t gib = 1024ULL * mib;

    if (value < 512ULL * mib) {
        return 0;
    }
    if (value < 2ULL * gib) {
        return 256ULL * mib;
    }
    if (value < 16ULL * gib) {
        return 1ULL * gib;
    }
    if (value < 64ULL * gib) {
        return 2ULL * gib;
    }
    return 4ULL * gib;
}

static NSNumber *LHStorageCapacityBucketedNumber(id value) {
    if (![value isKindOfClass:[NSNumber class]]) {
        return nil;
    }

    long long signedValue = [(NSNumber *)value longLongValue];
    if (signedValue < 0) {
        return nil;
    }

    uint64_t raw = (uint64_t)signedValue;
    uint64_t bucketSize = LHStorageCapacityBucketSize(raw);
    if (bucketSize == 0) {
        return (NSNumber *)value;
    }

    uint64_t bucketed = raw - (raw % bucketSize);
    if (bucketed == 0) {
        bucketed = bucketSize;
    }
    if (bucketed > raw) {
        bucketed = raw;
    }

    return [NSNumber numberWithUnsignedLongLong:bucketed];
}

static BOOL LHStorageCapacityDictionaryWantsKey(NSArray<NSURLResourceKey> *keys) {
    for (NSURLResourceKey key in keys) {
        if (LHStorageCapacityKeyIsCovered(key)) {
            return YES;
        }
    }
    return NO;
}

static BOOL LHStorageCapacityRewriteDictionary(NSMutableDictionary<NSURLResourceKey, id> *values) {
    BOOL changed = NO;
    NSURLResourceKey keys[] = {
        NSURLVolumeAvailableCapacityKey,
        NSURLVolumeAvailableCapacityForImportantUsageKey,
        NSURLVolumeAvailableCapacityForOpportunisticUsageKey
    };

    for (size_t i = 0; i < sizeof(keys) / sizeof(keys[0]); i++) {
        id original = values[keys[i]];
        NSNumber *bucketed = LHStorageCapacityBucketedNumber(original);
        if (bucketed != nil && bucketed != original && ![bucketed isEqual:original]) {
            values[keys[i]] = bucketed;
            changed = YES;
        }
    }
    return changed;
}

static BOOL LHStorageCapacityGetResourceValueReplacement(NSURL *self, SEL selector, id _Nullable *value, NSURLResourceKey key, NSError **error) {
    if (LHStorageCapacityGetResourceValueOriginalImplementation == 0) {
        return NO;
    }

    BOOL result = LHStorageCapacityGetResourceValueOriginalImplementation(self, selector, value, key, error);
    if (!result || value == nil || !LHStorageCapacityKeyIsCovered(key)) {
        return result;
    }

    NSNumber *bucketed = LHStorageCapacityBucketedNumber(*value);
    if (bucketed != nil) {
        *value = bucketed;
    }
    return result;
}

static NSDictionary<NSURLResourceKey, id> *LHStorageCapacityResourceValuesReplacement(NSURL *self, SEL selector, NSArray<NSURLResourceKey> *keys, NSError **error) {
    if (LHStorageCapacityResourceValuesOriginalImplementation == 0) {
        return nil;
    }

    NSDictionary<NSURLResourceKey, id> *original = LHStorageCapacityResourceValuesOriginalImplementation(self, selector, keys, error);
    if (original == nil || !LHStorageCapacityDictionaryWantsKey(keys)) {
        return original;
    }

    NSMutableDictionary<NSURLResourceKey, id> *values = [original mutableCopy];
    if (!LHStorageCapacityRewriteDictionary(values)) {
        return original;
    }
    return values;
}

bool LHMitigation_storage_available_capacity_foundation_bucketed_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class targetClass = NSClassFromString(@"NSURL");
    if (targetClass == Nil) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_storage_available_capacity_foundation_bucketed);
    }

    bool installed = false;
    SEL getResourceValueSelector = sel_registerName("getResourceValue:forKey:error:");
    SEL resourceValuesSelector = sel_registerName("resourceValuesForKeys:error:");

    if (getResourceValueSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             targetClass,
                                             getResourceValueSelector,
                                             (void *)LHStorageCapacityGetResourceValueReplacement,
                                             (void **)&LHStorageCapacityGetResourceValueOriginalImplementation) || installed;
    }
    if (resourceValuesSelector != 0) {
        installed = LHHookBackendHookMessage(backend,
                                             targetClass,
                                             resourceValuesSelector,
                                             (void *)LHStorageCapacityResourceValuesReplacement,
                                             (void **)&LHStorageCapacityResourceValuesOriginalImplementation) || installed;
    }

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_storage_available_capacity_foundation_bucketed);
    }
    return true;
}
