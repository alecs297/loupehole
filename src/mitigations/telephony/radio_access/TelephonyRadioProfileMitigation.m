#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef id (*LHTelephonyGetter)(id self, SEL selector);
typedef void (*LHTelephonySetter)(id self, SEL selector, id value);
typedef void (^LHServiceNotifier)(NSString *identifier);
typedef void (^LHCarrierNotifier)(id carrier);

static LHTelephonyGetter LHServiceRATOriginalImplementation;
static LHTelephonyGetter LHCurrentRATOriginalImplementation;
static LHTelephonyGetter LHDataServiceOriginalImplementation;
static LHTelephonyGetter LHServiceProvidersOriginalImplementation;
static LHTelephonyGetter LHProviderOriginalImplementation;
static LHTelephonyGetter LHCarrierNameOriginalImplementation;
static LHTelephonyGetter LHMCCOriginalImplementation;
static LHTelephonyGetter LHMNCOriginalImplementation;
static LHTelephonyGetter LHCountryOriginalImplementation;
static LHTelephonySetter LHSetServiceNotifierOriginalImplementation;
static LHTelephonySetter LHSetCarrierNotifierOriginalImplementation;
static BOOL LHTelephonyServicesEnabled;
static BOOL LHTelephonyLegacyRATEnabled;
static BOOL LHTelephonyCarrierRedactionEnabled;
static BOOL LHTelephonyServiceNotifierEnabled;
static BOOL LHTelephonyCarrierNotifierEnabled;
static __thread unsigned int LHTelephonyOriginalDepth;
static char LHServiceNotifierStateKey;
static char LHCarrierNotifierStateKey;
static NSString * const LHServiceAlias = @"0000000000000000";

/* Framework getters may call one another; internal reads must keep real keys. */
static id LHTelephonyReadOriginal(id self, SEL selector, LHTelephonyGetter getter) {
    if (self == nil || getter == 0) {
        return nil;
    }
    LHTelephonyOriginalDepth++;
    @try {
        return getter(self, selector);
    } @finally {
        LHTelephonyOriginalDepth--;
    }
}

static BOOL LHTelephonyHasValue(id value) {
    return [value isKindOfClass:[NSString class]] && [value length] != 0 &&
           ![value isEqualToString:@"--"] && ![value isEqualToString:@"65535"];
}

static NSString *LHTelephonyServiceIdentifier(NSString *original) {
    return LHTelephonyServicesEnabled && LHTelephonyHasValue(original) ? LHServiceAlias : original;
}

typedef struct LHTelephonyServices {
    NSDictionary *radios;
    NSDictionary *providers;
    NSString *identifier;
    NSString *selected;
    BOOL normalize;
} LHTelephonyServices;

static BOOL LHTelephonyValidDictionary(id dictionary, BOOL providers) {
    if (dictionary == nil) {
        return YES;
    }
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    Class carrierClass = NSClassFromString(@"CTCarrier");
    for (id key in dictionary) {
        id value = [dictionary objectForKey:key];
        if (!LHTelephonyHasValue(key) ||
            (providers ? ![value isKindOfClass:carrierClass] : ![value isKindOfClass:[NSString class]])) {
            return NO;
        }
    }
    return YES;
}

static BOOL LHTelephonyContainsService(NSDictionary *dictionary, NSString *key) {
    return dictionary.count == 0 || [dictionary objectForKey:key] != nil;
}

static LHTelephonyServices LHTelephonyReadServices(id self, SEL selector, id original) {
    LHTelephonyServices services = { 0 };
    if (self == nil || !LHTelephonyServicesEnabled) {
        return services;
    }
    SEL radioSelector = @selector(serviceCurrentRadioAccessTechnology);
    SEL providersSelector = @selector(serviceSubscriberCellularProviders);
    SEL identifierSelector = @selector(dataServiceIdentifier);
    @try {
        services.radios = selector == radioSelector ? original :
            LHTelephonyReadOriginal(self, radioSelector, LHServiceRATOriginalImplementation);
        services.providers = selector == providersSelector ? original :
            LHTelephonyReadOriginal(self, providersSelector, LHServiceProvidersOriginalImplementation);
        services.identifier = selector == identifierSelector ? original :
            LHTelephonyReadOriginal(self, identifierSelector, LHDataServiceOriginalImplementation);
    } @catch (NSException *exception) {
        (void)exception;
        return services;
    }
    if (!LHTelephonyValidDictionary(services.radios, NO) ||
        !LHTelephonyValidDictionary(services.providers, YES) ||
        (services.identifier != nil && ![services.identifier isKindOfClass:[NSString class]])) {
        return services;
    }

    if (LHTelephonyHasValue(services.identifier)) {
        services.selected = services.identifier;
    } else if (services.identifier.length == 0) {
        NSDictionary *candidates = services.radios.count != 0 ? services.radios : services.providers;
        for (NSString *key in [[candidates allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
            if (LHTelephonyContainsService(services.radios, key) &&
                LHTelephonyContainsService(services.providers, key)) {
                if (services.selected == nil || LHTelephonyHasValue(services.radios[key])) {
                    services.selected = key;
                }
                if (LHTelephonyHasValue(services.radios[key])) {
                    break;
                }
            }
        }
    }

    services.normalize = services.selected != nil &&
        LHTelephonyContainsService(services.radios, services.selected) &&
        LHTelephonyContainsService(services.providers, services.selected);
    return services;
}

static id LHTelephonyServiceRATReplacement(id self, SEL selector) {
    id original = LHTelephonyReadOriginal(self, selector, LHServiceRATOriginalImplementation);
    if (LHTelephonyOriginalDepth != 0 || ![original isKindOfClass:[NSDictionary class]] || [original count] == 0) {
        return original;
    }
    LHTelephonyServices services = LHTelephonyReadServices(self, selector, original);
    if (!services.normalize || services.radios.count == 0) {
        return original;
    }
    NSString *radio = services.radios[services.selected];
    return @{ LHServiceAlias: LHTelephonyHasValue(radio) ? CTRadioAccessTechnologyLTE : radio };
}

static id LHTelephonyCurrentRATReplacement(id self, SEL selector) {
    id original = LHTelephonyReadOriginal(self, selector, LHCurrentRATOriginalImplementation);
    if (LHTelephonyOriginalDepth != 0 || !LHTelephonyLegacyRATEnabled || !LHTelephonyHasValue(original)) {
        return original;
    }
    if (LHTelephonyServicesEnabled) {
        LHTelephonyServices services = LHTelephonyReadServices(self, NULL, nil);
        if (!services.normalize || !LHTelephonyHasValue(services.radios[services.selected])) {
            return original;
        }
    }
    return CTRadioAccessTechnologyLTE;
}

static id LHTelephonyDataServiceReplacement(id self, SEL selector) {
    id original = LHTelephonyReadOriginal(self, selector, LHDataServiceOriginalImplementation);
    if (LHTelephonyOriginalDepth != 0 || !LHTelephonyHasValue(original)) {
        return original;
    }
    LHTelephonyServices services = LHTelephonyReadServices(self, selector, original);
    return services.normalize ? LHTelephonyServiceIdentifier(original) : original;
}

static id LHTelephonyServiceProvidersReplacement(id self, SEL selector) {
    id original = LHTelephonyReadOriginal(self, selector, LHServiceProvidersOriginalImplementation);
    if (LHTelephonyOriginalDepth != 0 || ![original isKindOfClass:[NSDictionary class]] || [original count] == 0) {
        return original;
    }
    LHTelephonyServices services = LHTelephonyReadServices(self, selector, original);
    return services.normalize && services.providers.count != 0 ?
        @{ LHServiceAlias: services.providers[services.selected] } : original;
}

static unsigned int LHTelephonyCarrierFieldShape(id value) {
    if (value == nil) {
        return 0;
    }
    if ([value isKindOfClass:[NSString class]]) {
        return [value length] == 0 ? 1 : (LHTelephonyHasValue(value) ? 2 : 3);
    }
    return 4;
}

static BOOL LHTelephonyCarrierShapesAgree(id original, id selected) {
    LHTelephonyGetter getters[] = { LHCarrierNameOriginalImplementation, LHMCCOriginalImplementation,
                                   LHMNCOriginalImplementation, LHCountryOriginalImplementation };
    SEL selectors[] = { @selector(carrierName), @selector(mobileCountryCode),
                        @selector(mobileNetworkCode), @selector(isoCountryCode) };
    for (size_t i = 0; i < sizeof(getters) / sizeof(getters[0]); i++) {
        if (getters[i] == 0) {
            return NO;
        }
        id first = nil;
        id second = nil;
        @try {
            first = LHTelephonyReadOriginal(original, selectors[i], getters[i]);
            second = LHTelephonyReadOriginal(selected, selectors[i], getters[i]);
        } @catch (NSException *exception) {
            (void)exception;
            return NO;
        }
        unsigned int shape = LHTelephonyCarrierFieldShape(first);
        if (shape == 4 || shape != LHTelephonyCarrierFieldShape(second) ||
            (shape == 3 && ![first isEqual:second])) {
            return NO;
        }
    }
    return YES;
}

static id LHTelephonyNormalizeProvider(id self, id original) {
    if (original == nil || LHTelephonyOriginalDepth != 0 || !LHTelephonyCarrierRedactionEnabled) {
        return original;
    }
    if (![original isKindOfClass:NSClassFromString(@"CTCarrier")]) {
        return original;
    }
    LHTelephonyServices services = LHTelephonyReadServices(self, @selector(subscriberCellularProvider), original);
    id selected = services.normalize ? services.providers[services.selected] : nil;
    return selected != nil && LHTelephonyCarrierShapesAgree(original, selected) ? selected : original;
}

static id LHTelephonyProviderReplacement(id self, SEL selector) {
    return LHTelephonyNormalizeProvider(self, LHTelephonyReadOriginal(self, selector, LHProviderOriginalImplementation));
}

static id LHTelephonyCarrierFieldReplacement(id self, SEL selector) {
    LHTelephonyGetter getter = 0;
    BOOL numeric = NO;
    if (selector == @selector(carrierName)) {
        getter = LHCarrierNameOriginalImplementation;
    } else if (selector == @selector(mobileCountryCode)) {
        getter = LHMCCOriginalImplementation;
        numeric = YES;
    } else if (selector == @selector(mobileNetworkCode)) {
        getter = LHMNCOriginalImplementation;
        numeric = YES;
    } else if (selector == @selector(isoCountryCode)) {
        getter = LHCountryOriginalImplementation;
    }
    id original = LHTelephonyReadOriginal(self, selector, getter);
    return LHTelephonyOriginalDepth == 0 && LHTelephonyCarrierRedactionEnabled && LHTelephonyHasValue(original) ?
        (numeric ? @"65535" : @"--") : original;
}

static void LHTelephonySetNotifierReplacement(id self, SEL selector, id block) {
    BOOL service = selector == @selector(setServiceSubscriberCellularProvidersDidUpdateNotifier:);
    LHTelephonySetter setter = service ? LHSetServiceNotifierOriginalImplementation : LHSetCarrierNotifierOriginalImplementation;
    if (setter == 0) {
        return;
    }
    BOOL enabled = service ? LHTelephonyServiceNotifierEnabled : LHTelephonyCarrierNotifierEnabled;
    if (!enabled || LHTelephonyOriginalDepth != 0) {
        setter(self, selector, block);
        return;
    }
    void *stateKey = service ? &LHServiceNotifierStateKey : &LHCarrierNotifierStateKey;
    id installedWrapper = objc_getAssociatedObject(self, stateKey);
    if (block != nil && block == installedWrapper) {
        setter(self, selector, block);
        return;
    }
    id applicationBlock = [block copy];
    NSHashTable *receiver = [NSHashTable weakObjectsHashTable];
    [receiver addObject:self];
    id wrapper = nil;
    @try {
        if (applicationBlock != nil) {
            if (service) {
                wrapper = [^(NSString *identifier) {
                    id info = [[receiver allObjects] firstObject];
                    LHTelephonyServices services = LHTelephonyReadServices(info, NULL, nil);
                    ((LHServiceNotifier)applicationBlock)(services.normalize ? LHTelephonyServiceIdentifier(identifier) : identifier);
                } copy];
            } else {
                wrapper = [^(id carrier) {
                    id info = [[receiver allObjects] firstObject];
                    ((LHCarrierNotifier)applicationBlock)(LHTelephonyNormalizeProvider(info, carrier));
                } copy];
            }
        }
        setter(self, selector, wrapper);
        objc_setAssociatedObject(self, stateKey, wrapper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } @finally {
        [wrapper release];
        [applicationBlock release];
    }
}

static bool LHTelephonyHookMessage(LHHookBackend *backend,
                                   NSString *className,
                                   const char *selectorName,
                                   void *replacement,
                                   void **original) {
    Class targetClass = NSClassFromString(className);
    SEL selector = sel_registerName(selectorName);
    if (targetClass == Nil || selector == 0 || class_getInstanceMethod(targetClass, selector) == 0) {
        return false;
    }
    return LHHookBackendHookMessage(backend, targetClass, selector, replacement, original) && *original != 0;
}

bool LHMitigation_telephony_radio_access_coretelephony_single_lte_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    (void)policy;
    bool installed = false;

    Class infoClass = NSClassFromString(@"CTTelephonyNetworkInfo");
    BOOL hasServices = class_getInstanceMethod(infoClass, @selector(serviceCurrentRadioAccessTechnology)) != 0;
    BOOL hasDataIdentifier = class_getInstanceMethod(infoClass, @selector(dataServiceIdentifier)) != 0;

#define LH_TELEPHONY_HOOK(className, name, replacement, original) \
    LHTelephonyHookMessage(backend, (className), (name), (void *)(replacement), (void **)&(original))

    BOOL radio = LH_TELEPHONY_HOOK(@"CTTelephonyNetworkInfo", "serviceCurrentRadioAccessTechnology", LHTelephonyServiceRATReplacement, LHServiceRATOriginalImplementation);
    BOOL providers = LH_TELEPHONY_HOOK(@"CTTelephonyNetworkInfo", "serviceSubscriberCellularProviders", LHTelephonyServiceProvidersReplacement, LHServiceProvidersOriginalImplementation);
    BOOL identifier = LH_TELEPHONY_HOOK(@"CTTelephonyNetworkInfo", "dataServiceIdentifier", LHTelephonyDataServiceReplacement, LHDataServiceOriginalImplementation);
    LHTelephonyServicesEnabled = radio && providers && (!hasDataIdentifier || identifier);
    LHTelephonyLegacyRATEnabled = !hasServices || LHTelephonyServicesEnabled;
    installed = radio || providers || identifier;
    installed = LH_TELEPHONY_HOOK(@"CTTelephonyNetworkInfo", "currentRadioAccessTechnology", LHTelephonyCurrentRATReplacement, LHCurrentRATOriginalImplementation) || installed;
    installed = LH_TELEPHONY_HOOK(@"CTTelephonyNetworkInfo", "subscriberCellularProvider", LHTelephonyProviderReplacement, LHProviderOriginalImplementation) || installed;

    BOOL name = LH_TELEPHONY_HOOK(@"CTCarrier", "carrierName", LHTelephonyCarrierFieldReplacement, LHCarrierNameOriginalImplementation);
    BOOL mcc = LH_TELEPHONY_HOOK(@"CTCarrier", "mobileCountryCode", LHTelephonyCarrierFieldReplacement, LHMCCOriginalImplementation);
    BOOL mnc = LH_TELEPHONY_HOOK(@"CTCarrier", "mobileNetworkCode", LHTelephonyCarrierFieldReplacement, LHMNCOriginalImplementation);
    BOOL country = LH_TELEPHONY_HOOK(@"CTCarrier", "isoCountryCode", LHTelephonyCarrierFieldReplacement, LHCountryOriginalImplementation);
    LHTelephonyCarrierRedactionEnabled = name && mcc && mnc && country;
    installed = name || mcc || mnc || country || installed;

    BOOL setServiceNotifier = LH_TELEPHONY_HOOK(@"CTTelephonyNetworkInfo", "setServiceSubscriberCellularProvidersDidUpdateNotifier:", LHTelephonySetNotifierReplacement, LHSetServiceNotifierOriginalImplementation);
    LHTelephonyServiceNotifierEnabled = setServiceNotifier && LHTelephonyServicesEnabled;
    BOOL setCarrierNotifier = LH_TELEPHONY_HOOK(@"CTTelephonyNetworkInfo", "setSubscriberCellularProviderDidUpdateNotifier:", LHTelephonySetNotifierReplacement, LHSetCarrierNotifierOriginalImplementation);
    LHTelephonyCarrierNotifierEnabled = setCarrierNotifier && LHTelephonyCarrierRedactionEnabled;
    installed = setServiceNotifier || setCarrierNotifier || installed;
#undef LH_TELEPHONY_HOOK

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_telephony_radio_access_coretelephony_single_lte);
    }
    return true;
}
