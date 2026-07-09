#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"

#import <CoreBluetooth/CoreBluetooth.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <string.h>

typedef void (*LHScanForPeripheralsOriginal)(id self, SEL selector, NSArray<CBUUID *> *serviceUUIDs, NSDictionary<NSString *, id> *options);
typedef BOOL (*LHIsScanningOriginal)(id self, SEL selector);
typedef NSString *(*LHPeripheralNameOriginal)(id self, SEL selector);
typedef NSUUID *(*LHPeripheralIdentifierOriginal)(id self, SEL selector);

LH_POLICY_SEED(bluetooth_peripheral_identifier)

static LHScanForPeripheralsOriginal LHScanForPeripheralsOriginalImplementation;
static LHIsScanningOriginal LHIsScanningOriginalImplementation;
static LHPeripheralNameOriginal LHPeripheralNameOriginalImplementation;
static LHPeripheralIdentifierOriginal LHPeripheralIdentifierOriginalImplementation;
static LHPolicyEngine *LHBluetoothPolicy;

static void LHBluetoothScanForPeripheralsReplacement(id self,
                                                     SEL selector,
                                                     NSArray<CBUUID *> *serviceUUIDs,
                                                     NSDictionary<NSString *, id> *options) {
    (void)self;
    (void)selector;
    (void)serviceUUIDs;
    (void)options;
}

static BOOL LHBluetoothIsScanningReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return NO;
}

static NSString *LHBluetoothPeripheralNameReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return nil;
}

static bool LHBluetoothUUIDStringFromBytes(const uint8_t bytes[16], char *output, size_t outputLength) {
    if (output == 0 || outputLength < 37) {
        return false;
    }
    uint8_t uuidBytes[16] = { 0 };
    memcpy(uuidBytes, bytes, sizeof(uuidBytes));
    uuidBytes[6] = (uint8_t)((uuidBytes[6] & 0x0f) | 0x40);
    uuidBytes[8] = (uint8_t)((uuidBytes[8] & 0x3f) | 0x80);

    static const char digits[] = "0123456789abcdef";
    size_t offset = 0;
    for (size_t index = 0; index < sizeof(uuidBytes); index++) {
        if (index == 4 || index == 6 || index == 8 || index == 10) {
            output[offset++] = '-';
        }
        output[offset++] = digits[(uuidBytes[index] >> 4) & 0x0f];
        output[offset++] = digits[uuidBytes[index] & 0x0f];
    }
    output[offset] = '\0';
    return true;
}

static NSUUID *LHBluetoothPeripheralIdentifierReplacement(id self, SEL selector) {
    if (LHPeripheralIdentifierOriginalImplementation == 0) {
        return nil;
    }

    NSUUID *original = LHPeripheralIdentifierOriginalImplementation(self, selector);
    if (original == nil || LHBluetoothPolicy == 0) {
        return original;
    }

    uuid_t originalBytes;
    [original getUUIDBytes:originalBytes];
    uint8_t mappedBytes[16] = { 0 };
    if (!LHMitigationDeriveBytes(&LHBluetoothPolicy->config.buildSeed,
                                 &LHGeneratedPolicySeed_bluetooth_peripheral_identifier,
                                 &LHBluetoothPolicy->appContext.scope,
                                 originalBytes,
                                 sizeof(originalBytes),
                                 mappedBytes,
                                 sizeof(mappedBytes))) {
        return original;
    }

    char uuidString[37] = { 0 };
    if (!LHBluetoothUUIDStringFromBytes(mappedBytes, uuidString, sizeof(uuidString))) {
        return original;
    }

    NSString *mappedString = [NSString stringWithUTF8String:uuidString];
    NSUUID *mapped = [[NSUUID alloc] initWithUUIDString:mappedString];
    return mapped != nil ? mapped : original;
}

static bool LHBluetoothHookMessage(LHHookBackend *backend,
                                   NSString *className,
                                   const char *selectorName,
                                   void *replacement,
                                   void **original) {
    Class targetClass = NSClassFromString(className);
    SEL selector = sel_registerName(selectorName);
    if (targetClass == Nil || selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, original);
}

bool LHMitigation_bluetooth_corebluetooth_scan_empty_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHBluetoothPolicy = policy;
    bool installed = false;

    installed = LHBluetoothHookMessage(backend, @"CBCentralManager", "scanForPeripheralsWithServices:options:", (void *)LHBluetoothScanForPeripheralsReplacement, (void **)&LHScanForPeripheralsOriginalImplementation) || installed;
    installed = LHBluetoothHookMessage(backend, @"CBCentralManager", "isScanning", (void *)LHBluetoothIsScanningReplacement, (void **)&LHIsScanningOriginalImplementation) || installed;
    installed = LHBluetoothHookMessage(backend, @"CBPeripheral", "name", (void *)LHBluetoothPeripheralNameReplacement, (void **)&LHPeripheralNameOriginalImplementation) || installed;
    installed = LHBluetoothHookMessage(backend, @"CBPeripheral", "identifier", (void *)LHBluetoothPeripheralIdentifierReplacement, (void **)&LHPeripheralIdentifierOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_bluetooth_corebluetooth_scan_empty);
    }
    return true;
}
