#import <Foundation/Foundation.h>

@interface LHPreferencePolicy : NSObject <NSCopying>
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSInteger scopeMode;
@property (nonatomic, assign) BOOL moduleFilterEnabled;
@property (nonatomic, copy) NSArray<NSNumber *> *moduleIDs;
@property (nonatomic, copy) NSString *customSeed;
/** Returns the default UI/runtime policy. */
+ (instancetype)defaultPolicy;
@end

@interface LHPreferenceStore : NSObject

/** Returns the shared preference-store instance rooted at the active install prefix. */
+ (instancetype)sharedStore;
/** Returns generated module metadata displayed by the preferences UI. */
+ (NSArray<NSDictionary<NSString *, id> *> *)availableModules;
/** Returns every generated module ID as an NSNumber array. */
+ (NSArray<NSNumber *> *)allModuleIDs;
/** Returns a short display label for a serialized scope mode. */
+ (NSString *)scopeLabelForMode:(NSInteger)mode;
/** Returns explanatory display text for a serialized scope mode. */
+ (NSString *)scopeDescriptionForMode:(NSInteger)mode;
/** Returns whether `seed` is a valid UUID string. */
+ (BOOL)isValidSeedString:(NSString *)seed;
/** Returns a canonical lowercase UUID string or nil when invalid. */
+ (NSString *)normalizedSeedString:(NSString *)seed;
/** Returns a freshly generated UUID seed string. */
+ (NSString *)randomSeedString;

/** Initializes a store rooted at `rootPrefix`. */
- (instancetype)initWithRootPrefix:(NSString *)rootPrefix;
/** Ensures the runtime policy file exists. */
- (BOOL)ensurePolicyWithError:(NSError **)error;
/** Returns the current default policy. */
- (LHPreferencePolicy *)defaultPolicy;
/** Returns the effective policy after applying a bundle override, if present. */
- (LHPreferencePolicy *)effectivePolicyForBundleIdentifier:(NSString *)bundleIdentifier;
/** Returns the explicit override policy for a bundle identifier. */
- (LHPreferencePolicy *)overridePolicyForBundleIdentifier:(NSString *)bundleIdentifier;
/** Returns all bundle-specific policy overrides. */
- (NSDictionary<NSString *, LHPreferencePolicy *> *)overridePolicies;
/** Returns whether a bundle-specific override exists. */
- (BOOL)hasOverrideForBundleIdentifier:(NSString *)bundleIdentifier;
/** Persists the default policy. */
- (BOOL)setDefaultPolicy:(LHPreferencePolicy *)policy error:(NSError **)error;
/** Persists a bundle-specific override policy. */
- (BOOL)setOverridePolicy:(LHPreferencePolicy *)policy forBundleIdentifier:(NSString *)bundleIdentifier error:(NSError **)error;
/** Removes a bundle-specific override policy. */
- (BOOL)removeOverrideForBundleIdentifier:(NSString *)bundleIdentifier error:(NSError **)error;
/** Resets all preference policy and runtime seed state. */
- (BOOL)resetAllWithError:(NSError **)error;
/** Replaces the package root seed with fresh random bytes. */
- (BOOL)resetRootSeedWithError:(NSError **)error;
/** Replaces a custom seed across policies, optionally excluding one bundle from association updates. */
- (BOOL)replaceCustomSeed:(NSString *)oldSeed withSeed:(NSString *)newSeed includingBundleIdentifier:(NSString *)bundleIdentifier error:(NSError **)error;
/** Rewrites the generated MobileSubstrate filter plist from current policy state. */
- (BOOL)refreshFilterWithError:(NSError **)error;

/** Returns the generated runtime policy file path. */
- (NSString *)policyPath;
/** Returns the generated loader dylib installation path. */
- (NSString *)loaderDylibPath;
/** Returns the generated MobileSubstrate filter path. */
- (NSString *)filterPath;
/** Returns the package preferences directory path. */
- (NSString *)preferencesDirectoryPath;
/** Returns the package support directory path. */
- (NSString *)supportDirectoryPath;
/** Returns the package cache directory path. */
- (NSString *)cacheDirectoryPath;
/** Returns the package root seed path. */
- (NSString *)rootSeedPath;
/** Returns the build seed embedded in preference metadata, or a runtime-only marker. */
- (NSString *)buildSeedString;
/** Returns the package root seed as UUID-shaped lowercase text when readable. */
- (NSString *)rootSeedUUIDString;

@end
