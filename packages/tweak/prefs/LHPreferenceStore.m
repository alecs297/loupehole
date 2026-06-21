#import "LHPreferenceStore.h"

#include "LHGeneratedConfig.h"
#include "LHGeneratedPreferenceMetadata.h"

#include <sys/stat.h>

#ifndef THEOS_PACKAGE_INSTALL_PREFIX
#define THEOS_PACKAGE_INSTALL_PREFIX ""
#endif

#define LH_PREF_ROOTLESS_NS(path) @THEOS_PACKAGE_INSTALL_PREFIX path

static NSString * const LHPreferenceErrorDomain = @"com.loupehole.preferences";
static NSString * const LHPreferenceAppFilterBundle = @"com.apple.UIKit";

@implementation LHPreferencePolicy

+ (instancetype)defaultPolicy {
    LHPreferencePolicy *policy = [[self alloc] init];
    policy.enabled = NO;
    policy.scopeMode = 0;
    policy.moduleFilterEnabled = NO;
    policy.moduleIDs = @[];
    return policy;
}

- (id)copyWithZone:(NSZone *)zone {
    LHPreferencePolicy *copy = [[[self class] allocWithZone:zone] init];
    copy.enabled = self.enabled;
    copy.scopeMode = self.scopeMode;
    copy.moduleFilterEnabled = self.moduleFilterEnabled;
    copy.moduleIDs = self.moduleIDs ?: @[];
    return copy;
}

@end

@interface LHPreferenceStore ()
@property (nonatomic, copy) NSString *rootPrefix;
@end

@implementation LHPreferenceStore

+ (instancetype)sharedStore {
    static LHPreferenceStore *store;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        store = [[LHPreferenceStore alloc] initWithRootPrefix:nil];
    });
    return store;
}

- (instancetype)initWithRootPrefix:(NSString *)rootPrefix {
    self = [super init];
    if (self) {
#if LH_PREFERENCES_TESTING
        NSString *overrideRoot = [[[NSProcessInfo processInfo] environment] objectForKey:@"LH_PREFERENCES_TEST_ROOT"];
        if ([overrideRoot length] > 0) {
            _rootPrefix = [overrideRoot copy];
        } else
#endif
        {
            _rootPrefix = [rootPrefix length] > 0 ? [rootPrefix copy] : LH_PREF_ROOTLESS_NS(@"");
        }
    }
    return self;
}

+ (NSArray<NSDictionary<NSString *, id> *> *)availableModules {
    NSMutableArray<NSDictionary<NSString *, id> *> *modules = [NSMutableArray array];
    for (size_t index = 0; index < LHPreferenceGeneratedModuleCount; index++) {
        const LHPreferenceGeneratedModule *module = &LHPreferenceGeneratedModules[index];
        NSString *identifier = module->identifier ? [NSString stringWithUTF8String:module->identifier] : @"";
        NSString *displayName = module->displayName ? [NSString stringWithUTF8String:module->displayName] : identifier;
        [modules addObject:@{
            @"moduleID": @(module->moduleID),
            @"identifier": identifier,
            @"displayName": displayName
        }];
    }
    return modules;
}

+ (NSArray<NSNumber *> *)allModuleIDs {
    NSMutableArray<NSNumber *> *moduleIDs = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *module in [self availableModules]) {
        NSNumber *moduleID = module[@"moduleID"];
        if (moduleID != nil) {
            [moduleIDs addObject:moduleID];
        }
    }
    return moduleIDs;
}

+ (NSString *)scopeLabelForMode:(NSInteger)mode {
    switch (mode) {
        case 0: return @"Per app install";
        case 1: return @"Per app";
        case 2: return @"Per vendor group";
        case 3: return @"Per shared app group";
        case 4: return @"Manual linked group";
        default: return @"Unknown";
    }
}

+ (NSString *)scopeExportLabelForMode:(NSInteger)mode {
    switch (mode) {
        case 0: return @"per-app-install";
        case 1: return @"per-app";
        case 2: return @"per-vendor-group";
        case 3: return @"per-shared-app-group";
        case 4: return @"manual-linked-group";
        default: return @"unknown";
    }
}

+ (NSInteger)scopeModeForExportLabel:(NSString *)label {
    if ([label isEqualToString:@"per-app-install"]) return 0;
    if ([label isEqualToString:@"per-app"]) return 1;
    if ([label isEqualToString:@"per-vendor-group"]) return 2;
    if ([label isEqualToString:@"per-shared-app-group"]) return 3;
    if ([label isEqualToString:@"manual-linked-group"]) return 4;
    return 0;
}

+ (NSString *)moduleIdentifierForID:(NSNumber *)moduleID {
    for (NSDictionary<NSString *, id> *module in [self availableModules]) {
        if ([module[@"moduleID"] isEqualToNumber:moduleID]) {
            return module[@"identifier"];
        }
    }
    return [moduleID stringValue];
}

- (NSString *)pathByAppendingRootlessComponent:(NSString *)component {
    NSString *prefix = self.rootPrefix ?: @"";
    if ([prefix length] == 0) {
        return component;
    }
    return [prefix stringByAppendingPathComponent:[component stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]]];
}

- (NSString *)preferencesDirectoryPath {
    NSString *parent = [NSString stringWithUTF8String:LHGeneratedConfigPackageStateParentDirectoryName];
    return [[self pathByAppendingRootlessComponent:@"/var/mobile/Library/Preferences"] stringByAppendingPathComponent:parent];
}

- (NSString *)supportDirectoryPath {
    NSString *parent = [NSString stringWithUTF8String:LHGeneratedConfigPackageStateParentDirectoryName];
    return [[self pathByAppendingRootlessComponent:@"/var/mobile/Library/Application Support"] stringByAppendingPathComponent:parent];
}

- (NSString *)cacheDirectoryPath {
    NSString *parent = [NSString stringWithUTF8String:LHGeneratedConfigPackageStateParentDirectoryName];
    return [[self pathByAppendingRootlessComponent:@"/var/mobile/Library/Caches"] stringByAppendingPathComponent:parent];
}

- (NSString *)policyPath {
    NSString *fileName = [NSString stringWithUTF8String:LHGeneratedConfigPackagePolicyFileName];
    return [[self preferencesDirectoryPath] stringByAppendingPathComponent:fileName];
}

- (NSString *)filterPath {
    return [self pathByAppendingRootlessComponent:@"/Library/MobileSubstrate/DynamicLibraries/runtime.plist"];
}

- (NSString *)rootSeedPath {
    NSString *seedRoot = [NSString stringWithUTF8String:LHGeneratedConfigPackageSeedRootDirectoryName];
    NSString *seedFile = [NSString stringWithUTF8String:LHGeneratedConfigPackageRootSeedFileName];
    return [[[self supportDirectoryPath] stringByAppendingPathComponent:seedRoot] stringByAppendingPathComponent:seedFile];
}

- (NSError *)errorWithDescription:(NSString *)description {
    return [NSError errorWithDomain:LHPreferenceErrorDomain code:1 userInfo:@{NSLocalizedDescriptionKey: description ?: @"Unknown preference error"}];
}

- (BOOL)writeString:(NSString *)string toPath:(NSString *)path error:(NSError **)error {
    NSString *directory = [path stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:error]) {
        return NO;
    }
    if (![string writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:error]) {
        return NO;
    }
    chmod([path fileSystemRepresentation], S_IRUSR | S_IWUSR);
    return YES;
}

- (BOOL)ensurePolicyWithError:(NSError **)error {
    NSString *path = [self policyPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        chmod([path fileSystemRepresentation], S_IRUSR | S_IWUSR);
        return YES;
    }
    return [self writeString:@"D|0|0|0|\n" toPath:path error:error];
}

- (NSArray<NSString *> *)policyLinesWithError:(NSError **)error {
    if (![self ensurePolicyWithError:error]) {
        return nil;
    }
    NSString *text = [NSString stringWithContentsOfFile:[self policyPath] encoding:NSUTF8StringEncoding error:error];
    if (text == nil) {
        return nil;
    }
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSString *line in [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([trimmed length] > 0) {
            [lines addObject:trimmed];
        }
    }
    return lines;
}

- (LHPreferencePolicy *)policyFromFields:(NSArray<NSString *> *)fields offset:(NSUInteger)offset {
    if ([fields count] < offset + 4) {
        return nil;
    }
    NSInteger enabled = [fields[offset] integerValue];
    NSInteger scope = [fields[offset + 1] integerValue];
    NSInteger hasModules = [fields[offset + 2] integerValue];
    if ((enabled != 0 && enabled != 1) || scope < 0 || scope > 4 || (hasModules != 0 && hasModules != 1)) {
        return nil;
    }

    NSMutableArray<NSNumber *> *moduleIDs = [NSMutableArray array];
    NSString *modulesText = fields[offset + 3];
    if ([modulesText length] > 0) {
        for (NSString *item in [modulesText componentsSeparatedByString:@","]) {
            if ([item length] == 0) {
                return nil;
            }
            NSInteger moduleID = [item integerValue];
            if (moduleID <= 0) {
                return nil;
            }
            NSNumber *boxed = @(moduleID);
            if (![moduleIDs containsObject:boxed]) {
                [moduleIDs addObject:boxed];
            }
        }
    }

    LHPreferencePolicy *policy = [LHPreferencePolicy defaultPolicy];
    policy.enabled = enabled == 1;
    policy.scopeMode = scope;
    policy.moduleFilterEnabled = hasModules == 1;
    policy.moduleIDs = moduleIDs;
    return policy;
}

- (NSMutableDictionary<NSString *, LHPreferencePolicy *> *)mutableOverridesFromLines:(NSArray<NSString *> *)lines defaultPolicy:(LHPreferencePolicy **)defaultPolicy {
    NSMutableDictionary<NSString *, LHPreferencePolicy *> *overrides = [NSMutableDictionary dictionary];
    LHPreferencePolicy *parsedDefault = nil;
    for (NSString *line in lines) {
        NSArray<NSString *> *fields = [line componentsSeparatedByString:@"|"];
        NSString *kind = [fields firstObject];
        if ([kind isEqualToString:@"D"]) {
            LHPreferencePolicy *policy = [self policyFromFields:fields offset:1];
            if (policy != nil) {
                parsedDefault = policy;
            }
        } else if ([kind isEqualToString:@"B"] && [fields count] >= 6) {
            NSString *bundleIdentifier = fields[1];
            LHPreferencePolicy *policy = [self policyFromFields:fields offset:2];
            if (policy != nil && [self isValidConfigurableBundleIdentifier:bundleIdentifier]) {
                overrides[bundleIdentifier] = policy;
            }
        }
    }
    if (defaultPolicy != NULL) {
        *defaultPolicy = parsedDefault ?: [LHPreferencePolicy defaultPolicy];
    }
    return overrides;
}

- (LHPreferencePolicy *)defaultPolicy {
    NSError *error = nil;
    NSArray<NSString *> *lines = [self policyLinesWithError:&error];
    LHPreferencePolicy *defaultPolicy = nil;
    [self mutableOverridesFromLines:lines ?: @[] defaultPolicy:&defaultPolicy];
    return defaultPolicy ?: [LHPreferencePolicy defaultPolicy];
}

- (NSDictionary<NSString *, LHPreferencePolicy *> *)overridePolicies {
    NSError *error = nil;
    NSArray<NSString *> *lines = [self policyLinesWithError:&error];
    LHPreferencePolicy *defaultPolicy = nil;
    return [self mutableOverridesFromLines:lines ?: @[] defaultPolicy:&defaultPolicy];
}

- (LHPreferencePolicy *)overridePolicyForBundleIdentifier:(NSString *)bundleIdentifier {
    return [self overridePolicies][bundleIdentifier];
}

- (BOOL)hasOverrideForBundleIdentifier:(NSString *)bundleIdentifier {
    return [self overridePolicyForBundleIdentifier:bundleIdentifier] != nil;
}

- (LHPreferencePolicy *)effectivePolicyForBundleIdentifier:(NSString *)bundleIdentifier {
    LHPreferencePolicy *override = [self overridePolicyForBundleIdentifier:bundleIdentifier];
    return override ?: [self defaultPolicy];
}

- (NSString *)lineForDefaultPolicy:(LHPreferencePolicy *)policy {
    return [NSString stringWithFormat:@"D|%d|%ld|%d|%@",
            policy.enabled ? 1 : 0,
            (long)policy.scopeMode,
            policy.moduleFilterEnabled ? 1 : 0,
            [self modulesTextForPolicy:policy]];
}

- (NSString *)lineForBundleIdentifier:(NSString *)bundleIdentifier policy:(LHPreferencePolicy *)policy {
    return [NSString stringWithFormat:@"B|%@|%d|%ld|%d|%@",
            bundleIdentifier,
            policy.enabled ? 1 : 0,
            (long)policy.scopeMode,
            policy.moduleFilterEnabled ? 1 : 0,
            [self modulesTextForPolicy:policy]];
}

- (NSString *)modulesTextForPolicy:(LHPreferencePolicy *)policy {
    if (![policy.moduleIDs count]) {
        return @"";
    }
    NSMutableArray<NSString *> *items = [NSMutableArray array];
    for (NSNumber *moduleID in policy.moduleIDs) {
        [items addObject:[moduleID stringValue]];
    }
    return [items componentsJoinedByString:@","];
}

- (BOOL)writeDefaultPolicy:(LHPreferencePolicy *)defaultPolicy overrides:(NSDictionary<NSString *, LHPreferencePolicy *> *)overrides error:(NSError **)error {
    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithObject:[self lineForDefaultPolicy:defaultPolicy ?: [LHPreferencePolicy defaultPolicy]]];
    NSArray<NSString *> *bundleIDs = [[overrides allKeys] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    for (NSString *bundleID in bundleIDs) {
        LHPreferencePolicy *policy = overrides[bundleID];
        if (policy != nil && [self isValidConfigurableBundleIdentifier:bundleID]) {
            [lines addObject:[self lineForBundleIdentifier:bundleID policy:policy]];
        }
    }
    NSString *text = [[lines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
    return [self writeString:text toPath:[self policyPath] error:error];
}

- (BOOL)setDefaultPolicy:(LHPreferencePolicy *)policy error:(NSError **)error {
    NSArray<NSString *> *lines = [self policyLinesWithError:error];
    if (lines == nil) {
        return NO;
    }
    LHPreferencePolicy *unusedDefault = nil;
    NSMutableDictionary<NSString *, LHPreferencePolicy *> *overrides = [self mutableOverridesFromLines:lines defaultPolicy:&unusedDefault];
    if (![self writeDefaultPolicy:policy overrides:overrides error:error]) {
        return NO;
    }
    return [self refreshFilterWithError:error];
}

- (BOOL)setOverridePolicy:(LHPreferencePolicy *)policy forBundleIdentifier:(NSString *)bundleIdentifier error:(NSError **)error {
    if (![self isValidConfigurableBundleIdentifier:bundleIdentifier]) {
        if (error != NULL) {
            *error = [self errorWithDescription:@"Invalid or unsupported bundle identifier."];
        }
        return NO;
    }
    NSArray<NSString *> *lines = [self policyLinesWithError:error];
    if (lines == nil) {
        return NO;
    }
    LHPreferencePolicy *defaultPolicy = nil;
    NSMutableDictionary<NSString *, LHPreferencePolicy *> *overrides = [self mutableOverridesFromLines:lines defaultPolicy:&defaultPolicy];
    overrides[bundleIdentifier] = policy ?: [LHPreferencePolicy defaultPolicy];
    if (![self writeDefaultPolicy:defaultPolicy overrides:overrides error:error]) {
        return NO;
    }
    return [self refreshFilterWithError:error];
}

- (BOOL)removeOverrideForBundleIdentifier:(NSString *)bundleIdentifier error:(NSError **)error {
    NSArray<NSString *> *lines = [self policyLinesWithError:error];
    if (lines == nil) {
        return NO;
    }
    LHPreferencePolicy *defaultPolicy = nil;
    NSMutableDictionary<NSString *, LHPreferencePolicy *> *overrides = [self mutableOverridesFromLines:lines defaultPolicy:&defaultPolicy];
    [overrides removeObjectForKey:bundleIdentifier];
    if (![self writeDefaultPolicy:defaultPolicy overrides:overrides error:error]) {
        return NO;
    }
    return [self refreshFilterWithError:error];
}

- (BOOL)resetAllWithError:(NSError **)error {
    if (![self writeDefaultPolicy:[LHPreferencePolicy defaultPolicy] overrides:@{} error:error]) {
        return NO;
    }
    return [self refreshFilterWithError:error];
}

- (BOOL)refreshFilterWithError:(NSError **)error {
    LHPreferencePolicy *defaultPolicy = [self defaultPolicy];
    NSDictionary<NSString *, LHPreferencePolicy *> *overrides = [self overridePolicies];
    NSMutableArray<NSString *> *bundles = [NSMutableArray array];
    if (defaultPolicy.enabled) {
        [bundles addObject:LHPreferenceAppFilterBundle];
    } else {
        NSArray<NSString *> *bundleIDs = [[overrides allKeys] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
        for (NSString *bundleID in bundleIDs) {
            LHPreferencePolicy *policy = overrides[bundleID];
            if (policy.enabled && [self isValidConfigurableBundleIdentifier:bundleID]) {
                [bundles addObject:bundleID];
            }
        }
    }

    NSDictionary *plist = @{@"Filter": @{@"Bundles": bundles}};
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListXMLFormat_v1_0 options:0 error:error];
    if (data == nil) {
        return NO;
    }

    NSString *filterPath = [self filterPath];
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:filterPath];
    if (!exists) {
        NSString *directory = [filterPath stringByDeletingLastPathComponent];
        if (![[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:error]) {
            return NO;
        }
    }
    BOOL wrote = [data writeToFile:filterPath options:(exists ? 0 : NSDataWritingAtomic) error:error];
    if (wrote) {
        chmod([filterPath fileSystemRepresentation], S_IRUSR | S_IWUSR);
    }
    return wrote;
}

- (BOOL)isValidConfigurableBundleIdentifier:(NSString *)bundleIdentifier {
    if (![bundleIdentifier isKindOfClass:[NSString class]] || [bundleIdentifier length] == 0) {
        return NO;
    }
    if ([bundleIdentifier isEqualToString:@"com.apple"] || [bundleIdentifier hasPrefix:@"com.apple."]) {
        return NO;
    }
    NSCharacterSet *allowed = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-"];
    if ([[bundleIdentifier stringByTrimmingCharactersInSet:allowed] length] != 0) {
        return NO;
    }
    unichar first = [bundleIdentifier characterAtIndex:0];
    return [[NSCharacterSet alphanumericCharacterSet] characterIsMember:first];
}

- (NSDictionary *)exportDictionaryForPolicy:(LHPreferencePolicy *)policy {
    id mitigations = @"all";
    if (policy.moduleFilterEnabled) {
        NSMutableArray<NSString *> *identifiers = [NSMutableArray array];
        for (NSNumber *moduleID in policy.moduleIDs) {
            [identifiers addObject:[[self class] moduleIdentifierForID:moduleID]];
        }
        mitigations = identifiers;
    }
    return @{
        @"enabled": @(policy.enabled),
        @"scope": [[self class] scopeExportLabelForMode:policy.scopeMode],
        @"mitigations": mitigations
    };
}

- (NSURL *)exportSettingsWithError:(NSError **)error {
    LHPreferencePolicy *defaultPolicy = [self defaultPolicy];
    NSDictionary<NSString *, LHPreferencePolicy *> *overrides = [self overridePolicies];
    NSMutableDictionary *exportedOverrides = [NSMutableDictionary dictionary];
    for (NSString *bundleID in [[overrides allKeys] sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
        exportedOverrides[bundleID] = [self exportDictionaryForPolicy:overrides[bundleID]];
    }

    NSMutableArray *modules = [NSMutableArray array];
    for (NSDictionary *module in [[self class] availableModules]) {
        [modules addObject:@{
            @"id": module[@"identifier"],
            @"moduleID": module[@"moduleID"]
        }];
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
    NSDictionary *export = @{
        @"format": @"com.loupehole.settings",
        @"schemaVersion": @1,
        @"exportedAt": [formatter stringFromDate:[NSDate date]],
        @"buildSeed": [self buildSeedString] ?: @"",
        @"modules": modules,
        @"default": [self exportDictionaryForPolicy:defaultPolicy],
        @"overrides": exportedOverrides
    };

    NSData *data = [NSPropertyListSerialization dataWithPropertyList:export format:NSPropertyListXMLFormat_v1_0 options:0 error:error];
    if (data == nil) {
        return nil;
    }

    NSArray<NSString *> *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *directory = [documents firstObject] ?: NSTemporaryDirectory();
    NSDateFormatter *nameFormatter = [[NSDateFormatter alloc] init];
    nameFormatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    nameFormatter.dateFormat = @"yyyyMMdd-HHmmss";
    NSString *fileName = [NSString stringWithFormat:@"Loupehole-Settings-%@.lh", [nameFormatter stringFromDate:[NSDate date]]];
    NSString *path = [directory stringByAppendingPathComponent:fileName];
    if (![data writeToFile:path options:NSDataWritingAtomic error:error]) {
        return nil;
    }
    return [NSURL fileURLWithPath:path];
}

- (NSString *)buildSeedString {
    if (!LHGeneratedConfigHasInstanceSeed) {
        return @"runtime-random";
    }
    const uint8_t *bytes = LHGeneratedConfigInstanceSeed.bytes;
    return [NSString stringWithFormat:@"%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5],
            bytes[6], bytes[7],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]];
}

- (NSString *)rootSeedHexString {
    NSData *data = [NSData dataWithContentsOfFile:[self rootSeedPath]];
    if ([data length] == 0) {
        return @"missing";
    }
    const unsigned char *bytes = [data bytes];
    NSMutableString *output = [NSMutableString stringWithCapacity:[data length] * 2];
    for (NSUInteger index = 0; index < [data length]; index++) {
        [output appendFormat:@"%02x", bytes[index]];
    }
    return output;
}

@end
