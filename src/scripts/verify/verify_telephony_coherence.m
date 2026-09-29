#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <objc/runtime.h>
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "../../mitigations/telephony/radio_access/TelephonyRadioProfileMitigation.m"

NSString * const CTRadioAccessTechnologyLTE = @"CTRadioAccessTechnologyLTE";

@implementation CTCarrier
- (NSString *)carrierName { return _testName; }
- (NSString *)mobileCountryCode { return _testMCC; }
- (NSString *)mobileNetworkCode { return _testMNC; }
- (NSString *)isoCountryCode { return _testCountry; }
- (void)dealloc {
    [_testName release];
    [_testMCC release];
    [_testMNC release];
    [_testCountry release];
    [super dealloc];
}
@end

@implementation CTTelephonyNetworkInfo
@synthesize serviceSubscriberCellularProvidersDidUpdateNotifier = _serviceSubscriberCellularProvidersDidUpdateNotifier;
@synthesize subscriberCellularProviderDidUpdateNotifier = _subscriberCellularProviderDidUpdateNotifier;
- (NSString *)dataServiceIdentifier { return _testIdentifier; }
- (NSDictionary *)serviceCurrentRadioAccessTechnology { return _testRadios; }
- (NSDictionary *)serviceSubscriberCellularProviders {
    if (_testThrowRead) {
        [NSException raise:@"fixture" format:@"getter failure"];
    }
    if (_testNestedRead) {
        assert([[self dataServiceIdentifier] isEqual:_testIdentifier]);
        assert([self serviceCurrentRadioAccessTechnology] == _testRadios);
    }
    return _testProviders;
}
- (CTCarrier *)subscriberCellularProvider { return _testProvider; }
- (NSString *)currentRadioAccessTechnology { return _testRadio; }
- (void)setServiceSubscriberCellularProvidersDidUpdateNotifier:(void (^)(NSString *))block {
    if (_testThrowSetter) {
        [NSException raise:@"fixture" format:@"setter failure"];
    }
    id copy = [block copy];
    [_serviceSubscriberCellularProvidersDidUpdateNotifier release];
    _serviceSubscriberCellularProvidersDidUpdateNotifier = copy;
}
- (void)dealloc {
    [_testIdentifier release];
    [_testRadios release];
    [_testProviders release];
    [_testProvider release];
    [_testRadio release];
    [_serviceSubscriberCellularProvidersDidUpdateNotifier release];
    [_subscriberCellularProviderDidUpdateNotifier release];
    [super dealloc];
}
@end

static const char *LHTestMode;
static unsigned int LHTestNoOps;

static bool LHTestHook(LHHookBackend *backend, Class target, SEL selector, void *replacement, void **original) {
    (void)backend;
    if (strcmp(LHTestMode, "no-hooks") == 0 ||
        (strcmp(LHTestMode, "partial-services") == 0 && selector == @selector(dataServiceIdentifier)) ||
        (strcmp(LHTestMode, "partial-carrier") == 0 && selector == @selector(mobileCountryCode)) ||
        (strcmp(LHTestMode, "partial-notifier") == 0 && selector == @selector(setServiceSubscriberCellularProvidersDidUpdateNotifier:))) {
        return false;
    }
    Method method = class_getInstanceMethod(target, selector);
    assert(method != NULL);
    *original = (void *)method_setImplementation(method, (IMP)replacement);
    return true;
}

static bool LHTestNoOp(LHHookBackend *backend, uint32_t moduleID) {
    (void)backend;
    assert(moduleID == LHModuleID_telephony_radio_access_coretelephony_single_lte);
    LHTestNoOps++;
    return true;
}

static CTCarrier *LHTestCarrier(NSString *name, NSString *country, NSString *mcc, NSString *mnc) {
    CTCarrier *carrier = [[[CTCarrier alloc] init] autorelease];
    carrier.testName = name;
    carrier.testCountry = country;
    carrier.testMCC = mcc;
    carrier.testMNC = mnc;
    carrier.allowsVOIP = YES;
    return carrier;
}

static void LHTestExpectActive(CTTelephonyNetworkInfo *info, CTCarrier *active) {
    assert([info.dataServiceIdentifier isEqual:LHServiceAlias]);
    assert(info.serviceCurrentRadioAccessTechnology.count == 1);
    assert([info.serviceCurrentRadioAccessTechnology[info.dataServiceIdentifier] isEqual:CTRadioAccessTechnologyLTE]);
    assert(info.serviceSubscriberCellularProviders.count == 1);
    assert(info.serviceSubscriberCellularProviders[info.dataServiceIdentifier] == active);
    assert(info.subscriberCellularProvider == active);
    assert([info.currentRadioAccessTechnology isEqual:CTRadioAccessTechnologyLTE]);
    assert([active.carrierName isEqual:@"--"]);
    assert([active.isoCountryCode isEqual:@"--"]);
    assert([active.mobileCountryCode isEqual:@"65535"]);
    assert([active.mobileNetworkCode isEqual:@"65535"]);
    assert(active.allowsVOIP);
}

int main(int argc, char **argv) {
    @autoreleasepool {
        LHTestMode = argc > 1 ? argv[1] : "complete";
        LHHookBackendVTable vtable = { .hookMessage = LHTestHook, .registerNoOp = LHTestNoOp };
        LHHookBackend backend = { .vtable = &vtable };
        assert(LHMitigation_telephony_radio_access_coretelephony_single_lte_install(&backend, NULL));
        CTTelephonyNetworkInfo *info = [[[CTTelephonyNetworkInfo alloc] init] autorelease];
        CTCarrier *first = LHTestCarrier(@"Carrier A", @"be", @"206", @"10");
        CTCarrier *second = LHTestCarrier(@"Carrier B", @"fr", @"208", @"01");
        info.testIdentifier = @"0000000100000002";
        info.testRadios = @{ @"0000000100000001": @"CTRadioAccessTechnologyNR", @"0000000100000002": @"CTRadioAccessTechnologyNRNSA" };
        info.testProviders = @{ @"0000000100000001": first, @"0000000100000002": second };
        info.testProvider = first;
        info.testRadio = @"CTRadioAccessTechnologyNR";

        if (strcmp(LHTestMode, "no-hooks") == 0 || strcmp(LHTestMode, "partial-services") == 0) {
            assert(info.dataServiceIdentifier == info.testIdentifier);
            assert(info.serviceCurrentRadioAccessTechnology == info.testRadios);
            assert(info.serviceSubscriberCellularProviders == info.testProviders);
            assert(info.currentRadioAccessTechnology == info.testRadio);
            assert(LHTestNoOps == (strcmp(LHTestMode, "no-hooks") == 0 ? 1u : 0u));
            __block NSString *event = nil;
            info.serviceSubscriberCellularProvidersDidUpdateNotifier = ^(NSString *identifier) { event = identifier; };
            info.serviceSubscriberCellularProvidersDidUpdateNotifier(info.testIdentifier);
            assert(event == info.testIdentifier);
            puts(LHTestMode);
            return 0;
        }
        if (strcmp(LHTestMode, "partial-carrier") == 0) {
            assert([second.carrierName isEqual:@"Carrier B"]);
            assert([second.isoCountryCode isEqual:@"fr"]);
            assert([second.mobileCountryCode isEqual:@"208"]);
            assert([second.mobileNetworkCode isEqual:@"01"]);
            assert(info.subscriberCellularProvider == first);
            puts(LHTestMode);
            return 0;
        }
        if (strcmp(LHTestMode, "partial-notifier") == 0) {
            __block NSString *event = nil;
            info.serviceSubscriberCellularProvidersDidUpdateNotifier = ^(NSString *identifier) { event = identifier; };
            info.serviceSubscriberCellularProvidersDidUpdateNotifier(info.testIdentifier);
            assert(event == info.testIdentifier);
            LHTestExpectActive(info, second);
            puts(LHTestMode);
            return 0;
        }

        LHTestExpectActive(info, second);
        info.testNestedRead = YES;
        LHTestExpectActive(info, second);
        info.testNestedRead = NO;
        info.testIdentifier = @"0000000100000001";
        LHTestExpectActive(info, first);
        info.testIdentifier = @"0000000100000002";

        info.testThrowRead = YES;
        assert(info.dataServiceIdentifier == info.testIdentifier);
        assert(info.serviceCurrentRadioAccessTechnology == info.testRadios);
        assert(info.currentRadioAccessTechnology == info.testRadio);
        @try {
            (void)info.serviceSubscriberCellularProviders;
            assert(NO);
        } @catch (NSException *exception) {
            assert([exception.name isEqual:@"fixture"]);
        }
        assert(LHTelephonyOriginalDepth == 0);
        info.testThrowRead = NO;
        LHTestExpectActive(info, second);

        __block NSString *event = nil;
        __block unsigned int calls = 0;
        info.serviceSubscriberCellularProvidersDidUpdateNotifier = ^(NSString *identifier) {
            event = identifier;
            calls++;
        };
        id wrapper = info.serviceSubscriberCellularProvidersDidUpdateNotifier;
        info.serviceSubscriberCellularProvidersDidUpdateNotifier = wrapper;
        assert(info.serviceSubscriberCellularProvidersDidUpdateNotifier == wrapper);
        info.serviceSubscriberCellularProvidersDidUpdateNotifier(@"0000000100000001");
        assert([event isEqual:LHServiceAlias] && calls == 1);
        info.serviceSubscriberCellularProvidersDidUpdateNotifier(nil);
        assert(event == nil && calls == 2);
        info.serviceSubscriberCellularProvidersDidUpdateNotifier(@"");
        assert([event isEqual:@""] && calls == 3);
        info.serviceSubscriberCellularProvidersDidUpdateNotifier(@"--");
        assert([event isEqual:@"--"] && calls == 4);
        info.testThrowSetter = YES;
        @try {
            info.serviceSubscriberCellularProvidersDidUpdateNotifier = ^(NSString *identifier) { (void)identifier; };
            assert(NO);
        } @catch (NSException *exception) {
            assert([exception.name isEqual:@"fixture"]);
        }
        info.testThrowSetter = NO;
        assert(info.serviceSubscriberCellularProvidersDidUpdateNotifier == wrapper);
        id queuedWrapper = [wrapper retain];
        info.serviceSubscriberCellularProvidersDidUpdateNotifier = ^(NSString *identifier) {
            event = identifier;
            calls += 10;
        };
        assert(info.serviceSubscriberCellularProvidersDidUpdateNotifier != wrapper);
        info.serviceSubscriberCellularProvidersDidUpdateNotifier(info.testIdentifier);
        assert([event isEqual:LHServiceAlias] && calls == 14);
        ((LHServiceNotifier)queuedWrapper)(info.testIdentifier);
        assert([event isEqual:LHServiceAlias] && calls == 15);
        [queuedWrapper release];
        info.serviceSubscriberCellularProvidersDidUpdateNotifier = nil;
        assert(info.serviceSubscriberCellularProvidersDidUpdateNotifier == nil);
        assert(objc_getAssociatedObject(info, &LHServiceNotifierStateKey) == nil);

        __block CTCarrier *carrierEvent = nil;
        info.subscriberCellularProviderDidUpdateNotifier = ^(CTCarrier *carrier) { carrierEvent = carrier; };
        info.subscriberCellularProviderDidUpdateNotifier(first);
        assert(carrierEvent == second);
        info.subscriberCellularProviderDidUpdateNotifier(nil);
        assert(carrierEvent == nil);
        info.subscriberCellularProviderDidUpdateNotifier = nil;
        assert(info.subscriberCellularProviderDidUpdateNotifier == nil);

        second.testName = nil;
        second.testCountry = @"";
        second.testMCC = @"65535";
        second.testMNC = @"--";
        assert(second.carrierName == nil && [second.isoCountryCode isEqual:@""]);
        assert([second.mobileCountryCode isEqual:@"65535"] && [second.mobileNetworkCode isEqual:@"--"]);
        assert(info.subscriberCellularProvider == first);
        first.testName = @"--";
        second.testName = @"65535";
        second.testCountry = @"be";
        second.testMCC = @"206";
        second.testMNC = @"10";
        assert(info.subscriberCellularProvider == first);
        first.testName = @"Carrier A";
        second.testName = @"Carrier B";
        second.testCountry = @"fr";
        second.testMCC = @"208";
        second.testMNC = @"01";

        info.testIdentifier = @"missing";
        assert(info.dataServiceIdentifier == info.testIdentifier);
        assert(info.serviceCurrentRadioAccessTechnology == info.testRadios);
        assert(info.serviceSubscriberCellularProviders == info.testProviders);
        assert(info.currentRadioAccessTechnology == info.testRadio);
        info.testIdentifier = nil;
        assert(info.dataServiceIdentifier == nil);
        assert(info.serviceSubscriberCellularProviders[LHServiceAlias] == first);
        info.testIdentifier = @"";
        assert([info.dataServiceIdentifier isEqual:@""]);
        assert(info.serviceCurrentRadioAccessTechnology.count == 1);

        info.testIdentifier = @"0000000100000001";
        info.testRadios = @{ @"0000000100000001": @"" };
        assert([info.serviceCurrentRadioAccessTechnology[LHServiceAlias] isEqual:@""]);
        info.testRadios = @{ @"0000000100000001": [NSNull null] };
        assert(info.serviceCurrentRadioAccessTechnology == info.testRadios);
        assert(info.serviceSubscriberCellularProviders == info.testProviders);
        assert(info.dataServiceIdentifier == info.testIdentifier);
        info.testRadios = @{};
        assert(info.serviceCurrentRadioAccessTechnology == info.testRadios);
        assert(info.serviceSubscriberCellularProviders.count == 1);
        info.testRadios = nil;
        assert(info.serviceCurrentRadioAccessTechnology == nil);
        info.testProviders = @{};
        assert(info.serviceSubscriberCellularProviders == info.testProviders);
        info.testProviders = nil;
        info.testProvider = nil;
        info.testIdentifier = nil;
        info.testRadio = nil;
        assert(info.serviceSubscriberCellularProviders == nil && info.subscriberCellularProvider == nil);
        assert(info.dataServiceIdentifier == nil && info.currentRadioAccessTechnology == nil);
        info.testRadio = @"";
        assert([info.currentRadioAccessTechnology isEqual:@""]);

        void (^saved)(NSString *) = nil;
        NSHashTable *weakInfo = [NSHashTable weakObjectsHashTable];
        @autoreleasepool {
            CTTelephonyNetworkInfo *temporary = [[CTTelephonyNetworkInfo alloc] init];
            [weakInfo addObject:temporary];
            temporary.serviceSubscriberCellularProvidersDidUpdateNotifier = ^(NSString *identifier) { event = identifier; };
            saved = [temporary.serviceSubscriberCellularProvidersDidUpdateNotifier copy];
            [temporary release];
        }
        assert(weakInfo.allObjects.count == 0);
        saved(@"old-service");
        assert([event isEqual:@"old-service"]);
        [saved release];
        puts("complete");
    }
    return 0;
}
