#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

typedef NSString *(*LHDeviceNameOriginal)(UIDevice *self, SEL selector);

static LHDeviceNameOriginal LHDeviceNameOriginalImplementation;

static NSString *LHGenericDeviceName(UIDevice *device) {
    if (device != nil && [device respondsToSelector:@selector(userInterfaceIdiom)] && [device userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        return @"iPad";
    }
    return @"iPhone";
}

static NSString *LHDeviceNameReplacement(UIDevice *self, SEL selector) {
    (void)selector;
    return LHGenericDeviceName(self);
}

bool LHMitigation_identity_device_name_uidevice_generic_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;

    Class targetClass = NSClassFromString(@"UIDevice");
    SEL selector = sel_registerName("name");
    if (targetClass == Nil || selector == 0) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_identity_device_name_uidevice_generic);
    }

    if (!LHHookBackendHookMessage(backend, targetClass, selector, (void *)LHDeviceNameReplacement, (void **)&LHDeviceNameOriginalImplementation)) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_identity_device_name_uidevice_generic);
    }

    return true;
}
