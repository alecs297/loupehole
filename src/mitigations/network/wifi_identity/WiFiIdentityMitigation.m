#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

typedef NSString *(*LHWiFiStringGetterOriginal)(id self, SEL selector);
typedef double (*LHWiFiDoubleGetterOriginal)(id self, SEL selector);
typedef NSInteger (*LHWiFiIntegerGetterOriginal)(id self, SEL selector);
typedef BOOL (*LHWiFiBoolGetterOriginal)(id self, SEL selector);
typedef CFDictionaryRef (*LHCNCopyCurrentNetworkInfoOriginal)(CFStringRef interfaceName);

#define LH_WIFI_SSID_LENGTH 12
#define LH_WIFI_BSSID_LENGTH 18

LH_POLICY_SEED(network_wifi_ssid)
LH_POLICY_SEED(network_wifi_bssid)

static LHWiFiStringGetterOriginal LHWiFiSSIDOriginalImplementation;
static LHWiFiStringGetterOriginal LHWiFiBSSIDOriginalImplementation;
static LHWiFiDoubleGetterOriginal LHWiFiSignalStrengthOriginalImplementation;
static LHWiFiIntegerGetterOriginal LHWiFiSecurityTypeOriginalImplementation;
static LHWiFiBoolGetterOriginal LHWiFiSecureOriginalImplementation;
static LHCNCopyCurrentNetworkInfoOriginal LHCNCopyCurrentNetworkInfoOriginalImplementation;
static LHPolicyEngine *LHWiFiIdentityPolicy;

static NSString *LHWiFiSyntheticSSID(void) {
    char ssid[LH_WIFI_SSID_LENGTH + 1] = { 0 };
    if (LHWiFiIdentityPolicy == 0 ||
        !LHMitigationDeriveASCIIString(&LHWiFiIdentityPolicy->config.buildSeed,
                                       &LHGeneratedPolicySeed_network_wifi_ssid,
                                       &LHWiFiIdentityPolicy->appContext.scope,
                                       "abcdefghijklmnopqrstuvwxyz0123456789",
                                       LH_WIFI_SSID_LENGTH,
                                       ssid,
                                       sizeof(ssid))) {
        return nil;
    }
    return [NSString stringWithUTF8String:ssid];
}

static NSString *LHWiFiSyntheticBSSID(void) {
    uint8_t bytes[6] = { 0 };
    if (LHWiFiIdentityPolicy == 0 ||
        !LHMitigationDeriveBytes(&LHWiFiIdentityPolicy->config.buildSeed,
                                 &LHGeneratedPolicySeed_network_wifi_bssid,
                                 &LHWiFiIdentityPolicy->appContext.scope,
                                 0,
                                 0,
                                 bytes,
                                 sizeof(bytes))) {
        return nil;
    }

    bytes[0] = (uint8_t)((bytes[0] | 0x02) & 0xfe);
    char bssid[LH_WIFI_BSSID_LENGTH] = { 0 };
    snprintf(bssid,
             sizeof(bssid),
             "%02x:%02x:%02x:%02x:%02x:%02x",
             bytes[0],
             bytes[1],
             bytes[2],
             bytes[3],
             bytes[4],
             bytes[5]);
    return [NSString stringWithUTF8String:bssid];
}

static NSString *LHWiFiSSIDReplacement(id self, SEL selector) {
    NSString *synthetic = LHWiFiSyntheticSSID();
    if (synthetic != nil) {
        return synthetic;
    }
    if (LHWiFiSSIDOriginalImplementation != 0) {
        return LHWiFiSSIDOriginalImplementation(self, selector);
    }
    return nil;
}

static NSString *LHWiFiBSSIDReplacement(id self, SEL selector) {
    NSString *synthetic = LHWiFiSyntheticBSSID();
    if (synthetic != nil) {
        return synthetic;
    }
    if (LHWiFiBSSIDOriginalImplementation != 0) {
        return LHWiFiBSSIDOriginalImplementation(self, selector);
    }
    return nil;
}

static double LHWiFiSignalStrengthReplacement(id self, SEL selector) {
    if (LHWiFiSignalStrengthOriginalImplementation == 0) {
        return 0.62;
    }

    double original = LHWiFiSignalStrengthOriginalImplementation(self, selector);
    if (original < 0.0 || original > 1.0) {
        return original;
    }
    return 0.62;
}

static NSInteger LHWiFiSecurityTypeReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return 2;
}

static BOOL LHWiFiSecureReplacement(id self, SEL selector) {
    (void)self;
    (void)selector;
    return YES;
}

static CFDictionaryRef LHWiFiCopyCaptiveNetworkReplacement(CFStringRef interfaceName) {
    if (LHCNCopyCurrentNetworkInfoOriginalImplementation == 0) {
        return 0;
    }

    CFDictionaryRef original = LHCNCopyCurrentNetworkInfoOriginalImplementation(interfaceName);
    if (original == 0) {
        return 0;
    }

    NSString *ssid = LHWiFiSyntheticSSID();
    NSString *bssid = LHWiFiSyntheticBSSID();
    if (ssid == nil || bssid == nil) {
        return original;
    }

    NSMutableDictionary *rewritten = [(__bridge NSDictionary *)original mutableCopy];
    CFRelease(original);
    if (rewritten == nil) {
        return 0;
    }

    NSData *ssidData = [ssid dataUsingEncoding:NSUTF8StringEncoding];
    rewritten[@"SSID"] = ssid;
    rewritten[@"BSSID"] = bssid;
    if (ssidData != nil) {
        rewritten[@"SSIDDATA"] = ssidData;
    }
    return (CFDictionaryRef)CFBridgingRetain(rewritten);
}

static bool LHWiFiHookMessage(LHHookBackend *backend, Class targetClass, const char *selectorName, void *replacement, void **original) {
    SEL selector = sel_registerName(selectorName);
    if (targetClass == Nil || selector == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, original);
}

bool LHMitigation_network_wifi_identity_nehotspot_scoped_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHWiFiIdentityPolicy = policy;

    bool installed = false;
    Class hotspotClass = NSClassFromString(@"NEHotspotNetwork");
    installed = LHWiFiHookMessage(backend,
                                  hotspotClass,
                                  "SSID",
                                  (void *)LHWiFiSSIDReplacement,
                                  (void **)&LHWiFiSSIDOriginalImplementation) || installed;
    installed = LHWiFiHookMessage(backend,
                                  hotspotClass,
                                  "BSSID",
                                  (void *)LHWiFiBSSIDReplacement,
                                  (void **)&LHWiFiBSSIDOriginalImplementation) || installed;
    installed = LHWiFiHookMessage(backend,
                                  hotspotClass,
                                  "signalStrength",
                                  (void *)LHWiFiSignalStrengthReplacement,
                                  (void **)&LHWiFiSignalStrengthOriginalImplementation) || installed;
    installed = LHWiFiHookMessage(backend,
                                  hotspotClass,
                                  "securityType",
                                  (void *)LHWiFiSecurityTypeReplacement,
                                  (void **)&LHWiFiSecurityTypeOriginalImplementation) || installed;
    installed = LHWiFiHookMessage(backend,
                                  hotspotClass,
                                  "isSecure",
                                  (void *)LHWiFiSecureReplacement,
                                  (void **)&LHWiFiSecureOriginalImplementation) || installed;

    void *captiveTarget = dlsym(RTLD_DEFAULT, "CNCopyCurrentNetworkInfo");
    if (captiveTarget != 0) {
        installed = LHHookBackendHookFunction(backend,
                                              captiveTarget,
                                              (void *)LHWiFiCopyCaptiveNetworkReplacement,
                                              (void **)&LHCNCopyCurrentNetworkInfoOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "CNCopyCurrentNetworkInfo",
                                                (void *)LHWiFiCopyCaptiveNetworkReplacement,
                                                (void **)&LHCNCopyCurrentNetworkInfoOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_network_wifi_identity_nehotspot_scoped);
    }
    return true;
}
