#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"
#include "LHGeneratedPolicyValueRegistry.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NSUUID *(*LHIDFVOriginal)(id self, SEL selector);

#define LH_IDFV_UUID_STRING_LENGTH 37

static LHIDFVOriginal LHIDFVOriginalImplementation;
static LHPolicyEngine *LHIDFVPolicy;

static NSUUID *LHIDFVReplacement(id self, SEL selector) {
    char uuid[LH_IDFV_UUID_STRING_LENGTH] = { 0 };
    LHPolicyValueRequest request = {
        .valueID = LHPolicyValueID_identifier_for_vendor,
        .expectedKind = LHPolicyValueKindUTF8String,
        .output = uuid,
        .outputLength = sizeof(uuid)
    };
    if (LHPolicyEngineCopyValue(LHIDFVPolicy, &request, 0)) {
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
