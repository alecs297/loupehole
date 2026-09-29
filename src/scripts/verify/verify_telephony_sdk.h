#ifndef LH_VERIFY_TELEPHONY_SDK_H
#define LH_VERIFY_TELEPHONY_SDK_H

#import <Foundation/Foundation.h>

extern NSString * const CTRadioAccessTechnologyLTE;

@interface CTCarrier : NSObject
@property(nonatomic, copy) NSString *testName;
@property(nonatomic, copy) NSString *testMCC;
@property(nonatomic, copy) NSString *testMNC;
@property(nonatomic, copy) NSString *testCountry;
@property(nonatomic) BOOL allowsVOIP;
@property(nonatomic, readonly) NSString *carrierName;
@property(nonatomic, readonly) NSString *mobileCountryCode;
@property(nonatomic, readonly) NSString *mobileNetworkCode;
@property(nonatomic, readonly) NSString *isoCountryCode;
@end

@interface CTTelephonyNetworkInfo : NSObject
@property(nonatomic, copy) NSString *testIdentifier;
@property(nonatomic, copy) NSDictionary *testRadios;
@property(nonatomic, copy) NSDictionary *testProviders;
@property(nonatomic, retain) CTCarrier *testProvider;
@property(nonatomic, copy) NSString *testRadio;
@property(nonatomic) BOOL testNestedRead;
@property(nonatomic) BOOL testThrowRead;
@property(nonatomic) BOOL testThrowSetter;
@property(nonatomic, readonly) NSString *dataServiceIdentifier;
@property(nonatomic, readonly) NSDictionary *serviceCurrentRadioAccessTechnology;
@property(nonatomic, readonly) NSDictionary *serviceSubscriberCellularProviders;
@property(nonatomic, readonly) CTCarrier *subscriberCellularProvider;
@property(nonatomic, readonly) NSString *currentRadioAccessTechnology;
@property(nonatomic, copy) void (^serviceSubscriberCellularProvidersDidUpdateNotifier)(NSString *);
@property(nonatomic, copy) void (^subscriberCellularProviderDidUpdateNotifier)(CTCarrier *);
@end

#endif
