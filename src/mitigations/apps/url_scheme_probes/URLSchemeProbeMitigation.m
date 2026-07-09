#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <dispatch/dispatch.h>

typedef BOOL (*LHCanOpenURLOriginal)(id self, SEL selector, NSURL *url);

static LHCanOpenURLOriginal LHCanOpenURLOriginalImplementation;

static bool LHURLSchemeIsAllowedCommonScheme(NSString *scheme) {
    if (![scheme isKindOfClass:[NSString class]] || [scheme length] == 0) {
        return false;
    }

    static NSSet<NSString *> *allowedSchemes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allowedSchemes = [[NSSet alloc] initWithObjects:
            @"http", @"https", @"mailto", @"tel", @"sms",
            @"facetime", @"facetime-audio", nil];
    });

    return [allowedSchemes containsObject:[scheme lowercaseString]];
}

/** Replacement for `-[UIApplication canOpenURL:]` that denies unknown schemes by default. */
static BOOL LHCanOpenURLReplacement(id self, SEL selector, NSURL *url) {
    if ([url isKindOfClass:[NSURL class]] &&
        LHURLSchemeIsAllowedCommonScheme([url scheme]) &&
        LHCanOpenURLOriginalImplementation != 0) {
        return LHCanOpenURLOriginalImplementation(self, selector, url);
    }

    return NO;
}

/** Installs URL-scheme probe suppression that denies unknown schemes by default. */
bool LHMitigation_apps_url_scheme_probes_uiapplication_default_false_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class targetClass = NSClassFromString(@"UIApplication");
    SEL selector = sel_registerName("canOpenURL:");
    if (targetClass == Nil || selector == 0) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_apps_url_scheme_probes_uiapplication_default_false);
    }

    if (!LHHookBackendHookMessage(backend, targetClass, selector, (void *)LHCanOpenURLReplacement, (void **)&LHCanOpenURLOriginalImplementation)) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_apps_url_scheme_probes_uiapplication_default_false);
    }

    return true;
}
