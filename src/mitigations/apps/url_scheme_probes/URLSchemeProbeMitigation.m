#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <dispatch/dispatch.h>

typedef BOOL (*LHCanOpenURLOriginal)(id self, SEL selector, NSURL *url);

static LHCanOpenURLOriginal LHCanOpenURLOriginalImplementation;

static bool LHURLSchemeIsProtectedProbe(NSString *scheme) {
    if (![scheme isKindOfClass:[NSString class]] || [scheme length] == 0) {
        return false;
    }

    static NSSet<NSString *> *protectedSchemes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        protectedSchemes = [[NSSet alloc] initWithObjects:
            @"whatsapp", @"tg", @"sgnl", @"fb", @"fb-messenger",
            @"instagram", @"barcelona", @"twitter", @"tiktok", @"snapchat",
            @"linkedin", @"reddit", @"discord", @"slack", @"zoomus",
            @"msteams", @"tesla", @"youtube", @"spotify", @"nflx",
            @"comgooglemaps", @"waze", @"uber", @"duolingo", @"tinder",
            @"deliveroo", @"googlechrome", @"firefox", @"microsoft-edge",
            @"ddgquicklink", @"googlegmail", @"ms-outlook", @"protonmail",
            @"paypal", @"onepassword", @"lastpass", @"github", @"pinterest",
            @"com.amazon.mobile.shopping", @"bumble", @"hinge", @"grindr",
            @"venmo", @"squarecash", @"lyft", @"doordash", @"twitch",
            @"steammobile", @"coinbase", @"protonvpn", nil];
    });

    return [protectedSchemes containsObject:[scheme lowercaseString]];
}

/** Replacement for `-[UIApplication canOpenURL:]` on known third-party probe schemes. */
static BOOL LHCanOpenURLReplacement(id self, SEL selector, NSURL *url) {
    if ([url isKindOfClass:[NSURL class]] && LHURLSchemeIsProtectedProbe([url scheme])) {
        return NO;
    }

    if (LHCanOpenURLOriginalImplementation != 0) {
        return LHCanOpenURLOriginalImplementation(self, selector, url);
    }

    return NO;
}

/** Installs URL-scheme probe suppression for the known installed-app probe list. */
bool LHMitigation_apps_url_scheme_probes_uiapplication_known_list_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class targetClass = NSClassFromString(@"UIApplication");
    SEL selector = sel_registerName("canOpenURL:");
    if (targetClass == Nil || selector == 0) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_apps_url_scheme_probes_uiapplication_known_list);
    }

    if (!LHHookBackendHookMessage(backend, targetClass, selector, (void *)LHCanOpenURLReplacement, (void **)&LHCanOpenURLOriginalImplementation)) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_apps_url_scheme_probes_uiapplication_known_list);
    }

    return true;
}
