#import "LHAppContext.h"

#import <Foundation/Foundation.h>

bool LHAppContextInitCurrent(LHAppContext *context) {
    if (context == 0) {
        return false;
    }

    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    return LHScopeInitPerApp(&context->scope, [bundleIdentifier UTF8String]);
}
