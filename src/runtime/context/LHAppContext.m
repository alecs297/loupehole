#import "LHAppContext.h"

#import <Foundation/Foundation.h>

#include <stdlib.h>
#include <string.h>

/** Initializes the current app context using the default per-install scope. */
bool LHAppContextInitCurrent(LHAppContext *context) {
    return LHAppContextInitCurrentWithScopeMode(context, LHScopeModePerAppInstall);
}

/** Safely invokes a zero-argument Objective-C selector when the target supports it. */
static id LHAppContextPerformSelector(id target, SEL selector) {
    if (target == nil || selector == 0 || ![target respondsToSelector:selector]) {
        return nil;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [target performSelector:selector];
#pragma clang diagnostic pop
}

/** Reads a test-only string override from the environment. */
static NSString *LHAppContextTestingString(const char *name) {
#if LH_STATE_TESTING
    const char *value = getenv(name);
    if (value != 0 && value[0] != '\0') {
        return [NSString stringWithUTF8String:value];
    }
#else
    (void)name;
#endif
    return nil;
}

/** Returns whether a bundle identifier belongs to Apple system software. */
static bool LHAppContextBundleIdentifierIsSystem(NSString *bundleIdentifier) {
    if (![bundleIdentifier isKindOfClass:[NSString class]] || [bundleIdentifier length] == 0) {
        return false;
    }
    return [bundleIdentifier isEqualToString:@"com.apple"] || [bundleIdentifier hasPrefix:@"com.apple."];
}

/** Compares a path against both normal and `/private`-prefixed roots. */
static bool LHAppContextPathHasPrefix(NSString *path, NSString *prefix) {
    return [path hasPrefix:prefix] || [path hasPrefix:[@"/private" stringByAppendingString:prefix]];
}

/** Returns whether a bundle/executable path lives under an installed-app root. */
static bool LHAppContextPathIsInstalledAppRoot(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || [path length] == 0) {
        return false;
    }

    return LHAppContextPathHasPrefix(path, @"/var/containers/Bundle/Application/") ||
           LHAppContextPathHasPrefix(path, @"/var/mobile/Containers/Bundle/Application/") ||
           LHAppContextPathHasPrefix(path, @"/Applications/") ||
           LHAppContextPathHasPrefix(path, @"/var/jb/Applications/") ||
           LHAppContextPathHasPrefix(path, @"/procursus/Applications/");
}

/** Returns whether a path points at a main `.app` bundle rather than an extension. */
static bool LHAppContextPathLooksLikeMainApp(NSString *path) {
    if (![path isKindOfClass:[NSString class]] || [path length] == 0) {
        return false;
    }
    if ([path containsString:@".appex/"] || [path hasSuffix:@".appex"]) {
        return false;
    }
    return [path containsString:@".app/"] || [path hasSuffix:@".app"];
}

/** Checks bundle and executable paths for a targetable app container. */
static bool LHAppContextPathsLookTargetable(NSString *bundlePath, NSString *executablePath) {
    NSString *paths[] = { bundlePath, executablePath };
    for (size_t i = 0; i < sizeof(paths) / sizeof(paths[0]); i++) {
        NSString *path = paths[i];
        if (![path isKindOfClass:[NSString class]]) {
            continue;
        }
        path = [path stringByStandardizingPath];
        if (LHAppContextPathIsInstalledAppRoot(path) && LHAppContextPathLooksLikeMainApp(path)) {
            return true;
        }
    }
    return false;
}

/** Reads the unhooked UIDevice IDFV string for vendor-scope grouping. */
static NSString *LHAppContextOriginalIDFVString(void) {
    Class deviceClass = NSClassFromString(@"UIDevice");
    id device = LHAppContextPerformSelector((id)deviceClass, NSSelectorFromString(@"currentDevice"));
    id identifier = LHAppContextPerformSelector(device, NSSelectorFromString(@"identifierForVendor"));
    id uuidString = LHAppContextPerformSelector(identifier, NSSelectorFromString(@"UUIDString"));
    if (![uuidString isKindOfClass:[NSString class]]) {
        return nil;
    }
    return uuidString;
}

/** Initializes the current app context and resolves the selected scope mode. */
bool LHAppContextInitCurrentWithScopeMode(LHAppContext *context, LHScopeMode mode) {
    if (!LHAppContextInitCurrentBundle(context)) {
        return false;
    }
    return LHAppContextResolveScope(context, mode);
}

/** Initializes bundle identity and targetability metadata for the current process. */
bool LHAppContextInitCurrentBundle(LHAppContext *context) {
    if (context == 0) {
        return false;
    }

    memset(context, 0, sizeof(*context));
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *bundleIdentifier = LHAppContextTestingString("LH_APP_CONTEXT_TEST_BUNDLE_ID");
    if (![bundleIdentifier isKindOfClass:[NSString class]] || [bundleIdentifier length] == 0) {
        bundleIdentifier = [mainBundle bundleIdentifier];
    }
    if (![bundleIdentifier isKindOfClass:[NSString class]] || [bundleIdentifier length] == 0) {
        bundleIdentifier = [[NSProcessInfo processInfo] processName];
    }

    NSString *bundlePath = LHAppContextTestingString("LH_APP_CONTEXT_TEST_BUNDLE_PATH");
    if (![bundlePath isKindOfClass:[NSString class]] || [bundlePath length] == 0) {
        bundlePath = [mainBundle bundlePath];
    }

    NSString *executablePath = LHAppContextTestingString("LH_APP_CONTEXT_TEST_EXECUTABLE_PATH");
    if (![executablePath isKindOfClass:[NSString class]] || [executablePath length] == 0) {
        NSArray<NSString *> *arguments = [[NSProcessInfo processInfo] arguments];
        executablePath = [arguments count] > 0 ? arguments[0] : nil;
    }

    const char *identifier = [bundleIdentifier UTF8String];
    size_t identifierLength = identifier == 0 ? 0 : strlen(identifier);
    if (identifierLength > 0 && identifierLength < sizeof(context->bundleIdentifier)) {
        memcpy(context->bundleIdentifier, identifier, identifierLength);
        context->bundleIdentifier[identifierLength] = '\0';
        context->bundleIdentifierLength = identifierLength;
    }
    context->systemBundle = LHAppContextBundleIdentifierIsSystem(bundleIdentifier);
    context->targetableApplication = !context->systemBundle && LHAppContextPathsLookTargetable(bundlePath, executablePath);
    return true;
}

/** Returns whether the context is a targetable non-system application. */
bool LHAppContextIsTargetableThirdPartyApplication(const LHAppContext *context) {
    return context != 0 && context->targetableApplication && !context->systemBundle;
}

/** Resolves the current scope identifier for the selected scope mode. */
bool LHAppContextResolveScope(LHAppContext *context, LHScopeMode mode) {
    if (context == 0) {
        return false;
    }

    const char *identifier = context->bundleIdentifierLength == 0 ? 0 : context->bundleIdentifier;

    switch (mode) {
        case LHScopeModePerAppInstall:
            return LHScopeInitPerAppInstall(&context->scope, identifier);
        case LHScopeModePerApp:
            return LHScopeInitPerApp(&context->scope, identifier);
        case LHScopeModePerVendorGroup: {
            NSString *vendorIdentifier = LHAppContextOriginalIDFVString();
            return LHScopeInitPerVendorGroup(&context->scope, [vendorIdentifier UTF8String] ?: identifier);
        }
        case LHScopeModeManualLinkedGroup:
            return LHScopeInitManualLinkedGroup(&context->scope, identifier);
    }

    return LHScopeInitPerAppInstall(&context->scope, identifier);
}
