#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "app_bundle/install_date/AppInstallDateValues.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <dlfcn.h>
#include <Security/Security.h>

typedef OSStatus (*LHSecItemCopyMatchingOriginal)(CFDictionaryRef query, CFTypeRef *result);
typedef OSStatus (*LHSecItemAddOriginal)(CFDictionaryRef attributes, CFTypeRef *result);
typedef OSStatus (*LHSecItemUpdateOriginal)(CFDictionaryRef query, CFDictionaryRef attributesToUpdate);
typedef OSStatus (*LHSecItemDeleteOriginal)(CFDictionaryRef query);
typedef BOOL (*LHUserDefaultsBoolForKeyOriginal)(NSUserDefaults *self, SEL selector, NSString *defaultName);
typedef id (*LHUserDefaultsObjectForKeyOriginal)(NSUserDefaults *self, SEL selector, NSString *defaultName);
typedef void (*LHUserDefaultsSetBoolOriginal)(NSUserDefaults *self, SEL selector, BOOL value, NSString *defaultName);
typedef void (*LHUserDefaultsSetObjectOriginal)(NSUserDefaults *self, SEL selector, id value, NSString *defaultName);

static LHSecItemCopyMatchingOriginal LHSecItemCopyMatchingOriginalImplementation;
static LHSecItemAddOriginal LHSecItemAddOriginalImplementation;
static LHSecItemUpdateOriginal LHSecItemUpdateOriginalImplementation;
static LHSecItemDeleteOriginal LHSecItemDeleteOriginalImplementation;
static LHUserDefaultsBoolForKeyOriginal LHUserDefaultsBoolForKeyOriginalImplementation;
static LHUserDefaultsObjectForKeyOriginal LHUserDefaultsObjectForKeyOriginalImplementation;
static LHUserDefaultsSetBoolOriginal LHUserDefaultsSetBoolOriginalImplementation;
static LHUserDefaultsSetObjectOriginal LHUserDefaultsSetObjectOriginalImplementation;
static LHPolicyEngine *LHPreviousInstallsPolicy;

static NSString *const LHPreviousInstallsService = @"co.mysk.loupe.installLog";
static NSString *const LHPreviousInstallsAccount = @"installDates";
static NSString *const LHPreviousInstallsDefaultsKey = @"KeychainInstallLog.hasRecorded";

static bool LHCFEqualString(CFTypeRef value, NSString *expected) {
    if (value == 0 || expected == nil || CFGetTypeID(value) != CFStringGetTypeID()) {
        return false;
    }
    return CFEqual(value, (__bridge CFStringRef)expected);
}

static bool LHPreviousInstallsMatchesQuery(CFDictionaryRef query) {
    if (query == 0 || CFGetTypeID(query) != CFDictionaryGetTypeID()) {
        return false;
    }

    CFTypeRef itemClass = CFDictionaryGetValue(query, kSecClass);
    CFTypeRef service = CFDictionaryGetValue(query, kSecAttrService);
    CFTypeRef account = CFDictionaryGetValue(query, kSecAttrAccount);
    return itemClass != 0 &&
           CFEqual(itemClass, kSecClassGenericPassword) &&
           LHCFEqualString(service, LHPreviousInstallsService) &&
           LHCFEqualString(account, LHPreviousInstallsAccount);
}

static NSData *LHPreviousInstallsSyntheticLogData(void) {
    double installTimestamp = 0.0;
    if (!LHAppInstallDateCopySyntheticTimestamp(LHPreviousInstallsPolicy, &installTimestamp)) {
        return nil;
    }

    NSDate *installDate = [NSDate dateWithTimeIntervalSince1970:installTimestamp];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];

    NSString *date = [formatter stringFromDate:installDate];
    if (![date isKindOfClass:[NSString class]] || [date length] == 0) {
        return nil;
    }

    NSString *json = [NSString stringWithFormat:@"[\"%@\"]", date];
    return [json dataUsingEncoding:NSUTF8StringEncoding];
}

static OSStatus LHPreviousInstallsCopyMatchingReplacement(CFDictionaryRef query, CFTypeRef *result) {
    if (LHPreviousInstallsMatchesQuery(query) && CFDictionaryGetValue(query, kSecReturnData) == kCFBooleanTrue) {
        NSData *data = LHPreviousInstallsSyntheticLogData();
        if (data != nil) {
            if (result != 0) {
                *result = CFRetain((__bridge CFDataRef)data);
            }
            return errSecSuccess;
        }
    }

    if (LHSecItemCopyMatchingOriginalImplementation != 0) {
        return LHSecItemCopyMatchingOriginalImplementation(query, result);
    }

    return errSecItemNotFound;
}

static OSStatus LHPreviousInstallsAddReplacement(CFDictionaryRef attributes, CFTypeRef *result) {
    if (LHPreviousInstallsMatchesQuery(attributes)) {
        if (result != 0) {
            NSData *data = LHPreviousInstallsSyntheticLogData();
            *result = data != nil ? CFRetain((__bridge CFDataRef)data) : 0;
        }
        return errSecSuccess;
    }

    if (LHSecItemAddOriginalImplementation != 0) {
        return LHSecItemAddOriginalImplementation(attributes, result);
    }

    return errSecUnimplemented;
}

static OSStatus LHPreviousInstallsUpdateReplacement(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    if (LHPreviousInstallsMatchesQuery(query)) {
        return errSecSuccess;
    }

    if (LHSecItemUpdateOriginalImplementation != 0) {
        return LHSecItemUpdateOriginalImplementation(query, attributesToUpdate);
    }

    return errSecUnimplemented;
}

static OSStatus LHPreviousInstallsDeleteReplacement(CFDictionaryRef query) {
    if (LHPreviousInstallsMatchesQuery(query)) {
        return errSecSuccess;
    }

    if (LHSecItemDeleteOriginalImplementation != 0) {
        return LHSecItemDeleteOriginalImplementation(query);
    }

    return errSecUnimplemented;
}

static BOOL LHPreviousInstallsBoolForKeyReplacement(NSUserDefaults *self, SEL selector, NSString *defaultName) {
    if ([defaultName isEqualToString:LHPreviousInstallsDefaultsKey]) {
        return YES;
    }

    if (LHUserDefaultsBoolForKeyOriginalImplementation != 0) {
        return LHUserDefaultsBoolForKeyOriginalImplementation(self, selector, defaultName);
    }

    return NO;
}

static id LHPreviousInstallsObjectForKeyReplacement(NSUserDefaults *self, SEL selector, NSString *defaultName) {
    if ([defaultName isEqualToString:LHPreviousInstallsDefaultsKey]) {
        return @YES;
    }

    if (LHUserDefaultsObjectForKeyOriginalImplementation != 0) {
        return LHUserDefaultsObjectForKeyOriginalImplementation(self, selector, defaultName);
    }

    return nil;
}

static void LHPreviousInstallsSetBoolReplacement(NSUserDefaults *self, SEL selector, BOOL value, NSString *defaultName) {
    if ([defaultName isEqualToString:LHPreviousInstallsDefaultsKey]) {
        return;
    }

    if (LHUserDefaultsSetBoolOriginalImplementation != 0) {
        LHUserDefaultsSetBoolOriginalImplementation(self, selector, value, defaultName);
    }
}

static void LHPreviousInstallsSetObjectReplacement(NSUserDefaults *self, SEL selector, id value, NSString *defaultName) {
    if ([defaultName isEqualToString:LHPreviousInstallsDefaultsKey]) {
        return;
    }

    if (LHUserDefaultsSetObjectOriginalImplementation != 0) {
        LHUserDefaultsSetObjectOriginalImplementation(self, selector, value, defaultName);
    }
}

static bool LHPreviousInstallsHookFunction(LHHookBackend *backend, const char *symbol, void *replacement, void **original) {
    void *target = dlsym(RTLD_DEFAULT, symbol);
    bool installed = false;
    if (target != 0) {
        installed = LHHookBackendHookFunction(backend, target, replacement, original) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend, symbol, replacement, original) || installed;
    return installed;
}

bool LHMitigation_install_history_loupe_keychain_log_fresh_install_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHPreviousInstallsPolicy = policy;

    bool installed = false;
    installed = LHPreviousInstallsHookFunction(backend, "SecItemCopyMatching", (void *)LHPreviousInstallsCopyMatchingReplacement, (void **)&LHSecItemCopyMatchingOriginalImplementation) || installed;
    installed = LHPreviousInstallsHookFunction(backend, "SecItemAdd", (void *)LHPreviousInstallsAddReplacement, (void **)&LHSecItemAddOriginalImplementation) || installed;
    installed = LHPreviousInstallsHookFunction(backend, "SecItemUpdate", (void *)LHPreviousInstallsUpdateReplacement, (void **)&LHSecItemUpdateOriginalImplementation) || installed;
    installed = LHPreviousInstallsHookFunction(backend, "SecItemDelete", (void *)LHPreviousInstallsDeleteReplacement, (void **)&LHSecItemDeleteOriginalImplementation) || installed;

    Class defaultsClass = NSClassFromString(@"NSUserDefaults");
    if (defaultsClass != Nil) {
        SEL boolSelector = sel_registerName("boolForKey:");
        SEL objectSelector = sel_registerName("objectForKey:");
        SEL setBoolSelector = sel_registerName("setBool:forKey:");
        SEL setObjectSelector = sel_registerName("setObject:forKey:");

        if (boolSelector != 0) {
            installed = LHHookBackendHookMessage(backend, defaultsClass, boolSelector, (void *)LHPreviousInstallsBoolForKeyReplacement, (void **)&LHUserDefaultsBoolForKeyOriginalImplementation) || installed;
        }
        if (objectSelector != 0) {
            installed = LHHookBackendHookMessage(backend, defaultsClass, objectSelector, (void *)LHPreviousInstallsObjectForKeyReplacement, (void **)&LHUserDefaultsObjectForKeyOriginalImplementation) || installed;
        }
        if (setBoolSelector != 0) {
            installed = LHHookBackendHookMessage(backend, defaultsClass, setBoolSelector, (void *)LHPreviousInstallsSetBoolReplacement, (void **)&LHUserDefaultsSetBoolOriginalImplementation) || installed;
        }
        if (setObjectSelector != 0) {
            installed = LHHookBackendHookMessage(backend, defaultsClass, setObjectSelector, (void *)LHPreviousInstallsSetObjectReplacement, (void **)&LHUserDefaultsSetObjectOriginalImplementation) || installed;
        }
    }

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_install_history_loupe_keychain_log_fresh_install);
    }

    return true;
}
