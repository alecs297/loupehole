#import <Foundation/Foundation.h>

@interface LHPreferencePolicy : NSObject <NSCopying>
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSInteger scopeMode;
@property (nonatomic, assign) BOOL moduleFilterEnabled;
@property (nonatomic, copy) NSArray<NSNumber *> *moduleIDs;
+ (instancetype)defaultPolicy;
@end

@interface LHPreferenceStore : NSObject

+ (instancetype)sharedStore;
+ (NSArray<NSDictionary<NSString *, id> *> *)availableModules;
+ (NSArray<NSNumber *> *)allModuleIDs;
+ (NSString *)scopeLabelForMode:(NSInteger)mode;
+ (NSString *)scopeExportLabelForMode:(NSInteger)mode;
+ (NSInteger)scopeModeForExportLabel:(NSString *)label;
+ (NSString *)moduleIdentifierForID:(NSNumber *)moduleID;

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
- (BOOL)refreshFilterWithError:(NSError **)error;
- (NSURL *)exportSettingsWithError:(NSError **)error;

- (NSString *)policyPath;
- (NSString *)filterPath;
- (NSString *)preferencesDirectoryPath;
- (NSString *)supportDirectoryPath;
- (NSString *)cacheDirectoryPath;
- (NSString *)rootSeedPath;
- (NSString *)buildSeedString;
- (NSString *)rootSeedHexString;

@end
