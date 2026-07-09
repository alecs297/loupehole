#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef id (*LHUbiquityIdentityTokenOriginal)(NSFileManager *self, SEL selector);

static LHUbiquityIdentityTokenOriginal LHUbiquityIdentityTokenOriginalImplementation;

static id LHUbiquityIdentityTokenReplacement(NSFileManager *self, SEL selector) {
    (void)self;
    (void)selector;
    return nil;
}

bool LHMitigation_account_ubiquity_token_filemanager_nil_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class targetClass = NSClassFromString(@"NSFileManager");
    SEL selector = sel_registerName("ubiquityIdentityToken");
    if (targetClass == Nil || selector == 0) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_account_ubiquity_token_filemanager_nil);
    }

    if (!LHHookBackendHookMessage(backend, targetClass, selector, (void *)LHUbiquityIdentityTokenReplacement, (void **)&LHUbiquityIdentityTokenOriginalImplementation)) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_account_ubiquity_token_filemanager_nil);
    }

    return true;
}
