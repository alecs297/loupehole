#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NSUUID *(*LHIDFVOriginal)(id self, SEL selector);

#define LH_IDFV_UUID_STRING_LENGTH 37

LH_POLICY_SEED(identifier_for_vendor, value, "identifier_for_vendor")

static LHIDFVOriginal LHIDFVOriginalImplementation;
static LHPolicyEngine *LHIDFVPolicy;

/** Replacement for `-[UIDevice identifierForVendor]`. */
static NSUUID *LHIDFVReplacement(id self, SEL selector) {
    char uuid[LH_IDFV_UUID_STRING_LENGTH] = { 0 };
    if (LHIDFVPolicy != 0 &&
        LHMitigationDeriveUUIDString(&LHIDFVPolicy->config.buildSeed,
                                &LHGeneratedPolicySeed_identifier_for_vendor_value,
                                &LHIDFVPolicy->appContext.scope,
                                uuid,
                                sizeof(uuid))) {
        NSString *uuidString = [NSString stringWithUTF8String:uuid];
        NSUUID *replacement = [[NSUUID alloc] initWithUUIDString:uuidString];
        if (replacement != nil) {
            return replacement;
        }
    }

    if (LHIDFVOriginalImplementation != 0) {
        return LHIDFVOriginalImplementation(self, selector);
    }

    return nil;
}

/** Installs the scoped IDFV hook. */
bool LHMitigation_identity_idfv_uidevice_scoped_uuid_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHIDFVPolicy = policy;

    Class targetClass = NSClassFromString(@"UIDevice");
    SEL selector = sel_registerName("identifierForVendor");
    if (targetClass == Nil || selector == 0) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_identity_idfv_uidevice_scoped_uuid);
    }

    if (!LHHookBackendHookMessage(backend, targetClass, selector, (void *)LHIDFVReplacement, (void **)&LHIDFVOriginalImplementation)) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_identity_idfv_uidevice_scoped_uuid);
    }

    return true;
}
