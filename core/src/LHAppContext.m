#import "LHAppContext.h"

#import <Foundation/Foundation.h>

bool LHAppContextInitCurrent(LHAppContext *context) {
    return LHAppContextInitCurrentWithScopeMode(context, LHScopeModePerApp);
}

bool LHAppContextInitCurrentWithScopeMode(LHAppContext *context, LHScopeMode mode) {
    if (context == 0) {
        return false;
    }

    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    const char *identifier = [bundleIdentifier UTF8String];

    switch (mode) {
        case LHScopeModePerApp:
            return LHScopeInitPerApp(&context->scope, identifier);
        case LHScopeModePerVendorGroup:
            return LHScopeInitPerVendorGroup(&context->scope, identifier);
        case LHScopeModePerSharedAppGroup:
            return LHScopeInitPerSharedAppGroup(&context->scope, identifier);
        case LHScopeModeManualLinkedGroup:
            return LHScopeInitManualLinkedGroup(&context->scope, identifier);
    }

    return LHScopeInitPerApp(&context->scope, identifier);
}
