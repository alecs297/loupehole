#import "LHAppContext.h"

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#include <dlfcn.h>

bool LHAppContextInitCurrent(LHAppContext *context) {
    return LHAppContextInitCurrentWithScopeMode(context, LHScopeModePerAppInstall);
}

static id LHAppContextPerformSelector(id target, SEL selector) {
    if (target == nil || selector == 0 || ![target respondsToSelector:selector]) {
        return nil;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [target performSelector:selector];
#pragma clang diagnostic pop
}

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

typedef CFTypeRef (*LHSecTaskCreateFromSelfFn)(CFAllocatorRef allocator);
typedef CFTypeRef (*LHSecTaskCopyValueForEntitlementFn)(CFTypeRef task, CFStringRef entitlement, CFErrorRef *error);

static void *LHAppContextSecuritySymbol(const char *name) {
    void *symbol = dlsym(RTLD_DEFAULT, name);
    if (symbol != 0) {
        return symbol;
    }

    void *security = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY | RTLD_LOCAL);
    if (security == 0) {
        return 0;
    }
    return dlsym(security, name);
}

static NSString *LHAppContextFirstApplicationGroup(void) {
    LHSecTaskCreateFromSelfFn createTask = (LHSecTaskCreateFromSelfFn)LHAppContextSecuritySymbol("SecTaskCreateFromSelf");
    LHSecTaskCopyValueForEntitlementFn copyEntitlement = (LHSecTaskCopyValueForEntitlementFn)LHAppContextSecuritySymbol("SecTaskCopyValueForEntitlement");
    if (createTask == 0 || copyEntitlement == 0) {
        return nil;
    }

    CFTypeRef task = createTask(kCFAllocatorDefault);
    if (task == 0) {
        return nil;
    }

    CFTypeRef value = copyEntitlement(task, CFSTR("com.apple.security.application-groups"), 0);
    CFRelease(task);
    if (value == 0) {
        return nil;
    }

    NSString *result = nil;
    if (CFGetTypeID(value) == CFArrayGetTypeID() && CFArrayGetCount((CFArrayRef)value) > 0) {
        CFTypeRef first = CFArrayGetValueAtIndex((CFArrayRef)value, 0);
        if (first != 0 && CFGetTypeID(first) == CFStringGetTypeID()) {
            result = [(NSString *)first copy];
        }
    }
    CFRelease(value);
    return result;
}

bool LHAppContextInitCurrentWithScopeMode(LHAppContext *context, LHScopeMode mode) {
    if (context == 0) {
        return false;
    }

    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    const char *identifier = [bundleIdentifier UTF8String];

    switch (mode) {
        case LHScopeModePerAppInstall:
            return LHScopeInitPerAppInstall(&context->scope, identifier);
        case LHScopeModePerApp:
            return LHScopeInitPerApp(&context->scope, identifier);
        case LHScopeModePerVendorGroup: {
            NSString *vendorIdentifier = LHAppContextOriginalIDFVString();
            return LHScopeInitPerVendorGroup(&context->scope, [vendorIdentifier UTF8String] ?: identifier);
        }
        case LHScopeModePerSharedAppGroup: {
            NSString *appGroupIdentifier = LHAppContextFirstApplicationGroup();
            return LHScopeInitPerSharedAppGroup(&context->scope, [appGroupIdentifier UTF8String] ?: identifier);
        }
        case LHScopeModeManualLinkedGroup:
            return LHScopeInitManualLinkedGroup(&context->scope, identifier);
    }

    return LHScopeInitPerAppInstall(&context->scope, identifier);
}
