#import <Foundation/Foundation.h>

@interface LHPreferencePolicy : NSObject <NSCopying>
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSInteger scopeMode;
@property (nonatomic, assign) BOOL moduleFilterEnabled;
@property (nonatomic, copy) NSArray<NSNumber *> *moduleIDs;
@property (nonatomic, copy) NSString *customSeed;
+ (instancetype)defaultPolicy;
@end

@interface LHPreferenceStore : NSObject

+ (instancetype)sharedStore;
+ (NSArray<NSDictionary<NSString *, id> *> *)availableModules;
+ (NSArray<NSNumber *> *)allModuleIDs;
+ (NSString *)scopeLabelForMode:(NSInteger)mode;
+ (NSString *)scopeDescriptionForMode:(NSInteger)mode;
+ (BOOL)isValidSeedString:(NSString *)seed;
+ (NSString *)normalizedSeedString:(NSString *)seed;
+ (NSString *)randomSeedString;

- (instancetype)initWithRootPrefix:(NSString *)rootPrefix;
- (BOOL)ensurePolicyWithError:(NSError **)error;
- (LHPreferencePolicy *)defaultPolicy;
- (LHPreferencePolicy *)effectivePolicyForBundleIdentifier:(NSString *)bundleIdentifier;
- (LHPreferencePolicy *)overridePolicyForBundleIdentifier:(NSString *)bundleIdentifier;
- (NSDictionary<NSString *, LHPreferencePolicy *> *)overridePolicies;
- (BOOL)hasOverrideForBundleIdentifier:(NSString *)bundleIdentifier;
- (BOOL)setDefaultPolicy:(LHPreferencePolicy *)policy error:(NSError **)error;
- (BOOL)setOverridePolicy:(LHPreferencePolicy *)policy forBundleIdentifier:(NSString *)bundleIdentifier error:(NSError **)error;
- (BOOL)removeOverrideForBundleIdentifier:(NSString *)bundleIdentifier error:(NSError **)error;
- (BOOL)resetAllWithError:(NSError **)error;
- (BOOL)resetRootSeedWithError:(NSError **)error;
- (BOOL)replaceCustomSeed:(NSString *)oldSeed withSeed:(NSString *)newSeed includingBundleIdentifier:(NSString *)bundleIdentifier error:(NSError **)error;
- (BOOL)refreshFilterWithError:(NSError **)error;

- (NSString *)policyPath;
- (NSString *)loaderDylibPath;
- (NSString *)filterPath;
- (NSString *)preferencesDirectoryPath;
- (NSString *)supportDirectoryPath;
- (NSString *)cacheDirectoryPath;
- (NSString *)rootSeedPath;
- (NSString *)buildSeedString;
- (NSString *)rootSeedHexString;

@end
