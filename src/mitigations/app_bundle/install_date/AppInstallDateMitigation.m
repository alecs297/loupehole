#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "AppInstallDateValues.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef BOOL (*LHAppInstallGetResourceValueOriginal)(NSURL *self, SEL selector, id _Nullable *value, NSURLResourceKey key, NSError **error);
typedef NSDictionary<NSURLResourceKey, id> *(*LHAppInstallResourceValuesOriginal)(NSURL *self, SEL selector, NSArray<NSURLResourceKey> *keys, NSError **error);

static LHAppInstallGetResourceValueOriginal LHAppInstallGetResourceValueOriginalImplementation;
static LHAppInstallResourceValuesOriginal LHAppInstallResourceValuesOriginalImplementation;
static LHPolicyEngine *LHAppInstallDatePolicy;

static NSDate *LHAppInstallDate(void) {
    double timestamp = 0.0;
    if (!LHAppInstallDateCopySyntheticTimestamp(LHAppInstallDatePolicy, &timestamp)) {
        return nil;
    }
    return [NSDate dateWithTimeIntervalSince1970:timestamp];
}

static BOOL LHStringEqualPath(NSString *left, NSString *right) {
    return [left isKindOfClass:[NSString class]] &&
           [right isKindOfClass:[NSString class]] &&
           [[left stringByStandardizingPath] isEqualToString:[right stringByStandardizingPath]];
}

static BOOL LHURLTargetsAppContainerRoot(NSURL *url) {
    if (![url isFileURL]) {
        return NO;
    }

    NSString *path = [[url path] stringByStandardizingPath];
    NSString *home = [NSHomeDirectory() stringByStandardizingPath];
    if (![path isKindOfClass:[NSString class]] || ![home isKindOfClass:[NSString class]] || [home length] == 0) {
        return NO;
    }

    NSString *documents = [home stringByAppendingPathComponent:@"Documents"];
    NSString *library = [home stringByAppendingPathComponent:@"Library"];
    NSString *caches = [library stringByAppendingPathComponent:@"Caches"];
    NSString *applicationSupport = [library stringByAppendingPathComponent:@"Application Support"];

    return LHStringEqualPath(path, documents) ||
           LHStringEqualPath(path, library) ||
           LHStringEqualPath(path, caches) ||
           LHStringEqualPath(path, applicationSupport);
}

static BOOL LHAppInstallGetResourceValueReplacement(NSURL *self, SEL selector, id _Nullable *value, NSURLResourceKey key, NSError **error) {
    BOOL originalResult = NO;
    if (LHAppInstallGetResourceValueOriginalImplementation != 0) {
        originalResult = LHAppInstallGetResourceValueOriginalImplementation(self, selector, value, key, error);
    }

    if (originalResult && [key isEqualToString:NSURLCreationDateKey] && LHURLTargetsAppContainerRoot(self)) {
        NSDate *date = LHAppInstallDate();
        if (date != nil) {
            if (value != nil) {
                *value = date;
            }
            return YES;
        }
    }

    return originalResult;
}

static NSDictionary<NSURLResourceKey, id> *LHAppInstallResourceValuesReplacement(NSURL *self, SEL selector, NSArray<NSURLResourceKey> *keys, NSError **error) {
    NSDictionary<NSURLResourceKey, id> *original = nil;
    if (LHAppInstallResourceValuesOriginalImplementation != 0) {
        original = LHAppInstallResourceValuesOriginalImplementation(self, selector, keys, error);
    }

    if (original == nil || ![keys containsObject:NSURLCreationDateKey] || !LHURLTargetsAppContainerRoot(self)) {
        return original;
    }

    NSDate *date = LHAppInstallDate();
    if (date == nil) {
        return original;
    }

    NSMutableDictionary<NSURLResourceKey, id> *values = [original mutableCopy];
    values[NSURLCreationDateKey] = date;
    return values;
}

bool LHMitigation_app_bundle_install_date_foundation_synthetic_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHAppInstallDatePolicy = policy;

    Class targetClass = NSClassFromString(@"NSURL");
    if (targetClass == Nil) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_app_bundle_install_date_foundation_synthetic);
    }

    bool installed = false;
    SEL getResourceValueSelector = sel_registerName("getResourceValue:forKey:error:");
    SEL resourceValuesSelector = sel_registerName("resourceValuesForKeys:error:");

    if (getResourceValueSelector != 0) {
        installed = LHHookBackendHookMessage(backend, targetClass, getResourceValueSelector, (void *)LHAppInstallGetResourceValueReplacement, (void **)&LHAppInstallGetResourceValueOriginalImplementation) || installed;
    }
    if (resourceValuesSelector != 0) {
        installed = LHHookBackendHookMessage(backend, targetClass, resourceValuesSelector, (void *)LHAppInstallResourceValuesReplacement, (void **)&LHAppInstallResourceValuesOriginalImplementation) || installed;
    }

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_app_bundle_install_date_foundation_synthetic);
    }

    return true;
}
