#import "LHPreferenceStore.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@interface PSSpecifier (LoupeholeValues)
@property (nonatomic, retain) NSArray *values;
@property (nonatomic, retain) NSArray *titles;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (NSArray *)allApplications;
@end

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *bundleIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSURL *bundleURL;
@property (nonatomic, readonly) NSString *applicationType;
@end

static NSString *LHPolicySummary(LHPreferencePolicy *policy, BOOL override) {
    NSString *state = policy.enabled ? @"On" : @"Off";
    if (override) {
        return [NSString stringWithFormat:@"Override: %@", state];
    }
    return [NSString stringWithFormat:@"Default: %@", state];
}

static void LHPresentError(UIViewController *controller, NSError *error) {
    NSString *message = error.localizedDescription ?: @"The settings could not be updated.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Loupehole" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [controller presentViewController:alert animated:YES completion:nil];
}

static PSSpecifier *LHGroupSpecifier(NSString *label, NSString *footer) {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:label target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
    if (footer != nil) {
        [specifier setProperty:footer forKey:@"footerText"];
    }
    return specifier;
}

static PSSpecifier *LHSwitchSpecifier(NSString *label, id target, NSString *key) {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:label
                                                           target:target
                                                              set:@selector(setPreferenceValue:specifier:)
                                                              get:@selector(readPreferenceValue:)
                                                           detail:nil
                                                             cell:PSSwitchCell
                                                             edit:nil];
    [specifier setProperty:key forKey:@"key"];
    return specifier;
}

static PSSpecifier *LHButtonSpecifier(NSString *label, id target, SEL action) {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:label target:target set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    specifier.buttonAction = action;
    return specifier;
}

static PSSpecifier *LHLinkSpecifier(NSString *label, id target, Class detail, SEL preview) {
    return [PSSpecifier preferenceSpecifierNamed:label target:target set:nil get:preview detail:detail cell:PSLinkListCell edit:nil];
}

static PSSpecifier *LHValueSpecifier(NSString *label, NSString *value) {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:label target:nil set:nil get:nil detail:nil cell:PSTitleValueCell edit:nil];
    [specifier setProperty:value ?: @"" forKey:@"value"];
    return specifier;
}

@interface LHPolicyListController : PSListController
@property (nonatomic, readonly) LHPreferenceStore *store;
- (LHPreferencePolicy *)policy;
- (BOOL)writePolicy:(LHPreferencePolicy *)policy error:(NSError **)error;
- (BOOL)showsOverrideReset;
- (void)resetOverride;
- (NSString *)moduleKeyForID:(NSNumber *)moduleID;
@end

@implementation LHPolicyListController

- (LHPreferenceStore *)store {
    return [LHPreferenceStore sharedStore];
}

- (LHPreferencePolicy *)policy {
    return [LHPreferencePolicy defaultPolicy];
}

- (BOOL)writePolicy:(LHPreferencePolicy *)policy error:(NSError **)error {
    (void)policy;
    (void)error;
    return NO;
}

- (BOOL)showsOverrideReset {
    return NO;
}

- (void)resetOverride {
}

- (NSString *)moduleKeyForID:(NSNumber *)moduleID {
    return [@"module." stringByAppendingString:[moduleID stringValue]];
}

- (PSSpecifier *)scopeSpecifier {
    LHPreferencePolicy *policy = [self policy];
    NSString *label = [NSString stringWithFormat:@"Scope: %@", [LHPreferenceStore scopeLabelForMode:policy.scopeMode]];
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:label
                                                           target:self
                                                              set:nil
                                                              get:nil
                                                           detail:nil
                                                             cell:PSButtonCell
                                                             edit:nil];
    [specifier setProperty:@"scope" forKey:@"key"];
    specifier.buttonAction = @selector(cycleScope);
    return specifier;
}

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *items = [NSMutableArray array];
        LHPreferencePolicy *policy = [self policy];
        BOOL customModules = policy.moduleFilterEnabled;

        [items addObject:LHGroupSpecifier(@"Policy", nil)];
        [items addObject:LHSwitchSpecifier(@"Enabled", self, @"enabled")];
        [items addObject:[self scopeSpecifier]];
        [items addObject:LHSwitchSpecifier(@"Custom mitigations", self, @"customModules")];

        [items addObject:LHGroupSpecifier(@"Mitigations", customModules ? nil : @"All compiled mitigations are enabled while custom mitigations is off.")];
        for (NSDictionary<NSString *, id> *module in [LHPreferenceStore availableModules]) {
            NSNumber *moduleID = module[@"moduleID"];
            NSString *label = module[@"displayName"];
            PSSpecifier *specifier = LHSwitchSpecifier(label, self, [self moduleKeyForID:moduleID]);
            [specifier setProperty:module[@"identifier"] forKey:@"subtitle"];
            [specifier setProperty:@(customModules) forKey:@"enabled"];
            [items addObject:specifier];
        }

        if ([self showsOverrideReset]) {
            [items addObject:LHGroupSpecifier(nil, nil)];
            [items addObject:LHButtonSpecifier(@"Reset App Override", self, @selector(confirmResetOverride))];
        }

        _specifiers = items;
    }
    return _specifiers;
}

- (void)confirmResetOverride {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset Override"
                                                                   message:@"This app will inherit the default profile again."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [self resetOverride];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)cycleScope {
    LHPreferencePolicy *policy = [[self policy] copy];
    policy.scopeMode = (policy.scopeMode + 1) % 5;
    NSError *error = nil;
    if (![self writePolicy:policy error:&error]) {
        LHPresentError(self, error);
        return;
    }
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    LHPreferencePolicy *policy = [[self policy] copy];
    if ([key isEqualToString:@"enabled"]) {
        policy.enabled = [value boolValue];
    } else if ([key isEqualToString:@"scope"]) {
        policy.scopeMode = [value integerValue];
    } else if ([key isEqualToString:@"customModules"]) {
        policy.moduleFilterEnabled = [value boolValue];
        if (policy.moduleFilterEnabled && [policy.moduleIDs count] == 0) {
            policy.moduleIDs = [LHPreferenceStore allModuleIDs];
        } else if (!policy.moduleFilterEnabled) {
            policy.moduleIDs = @[];
        }
    } else if ([key hasPrefix:@"module."]) {
        NSNumber *moduleID = @([[key substringFromIndex:[@"module." length]] integerValue]);
        NSMutableArray<NSNumber *> *moduleIDs = [NSMutableArray arrayWithArray:policy.moduleIDs ?: @[]];
        if ([value boolValue] && ![moduleIDs containsObject:moduleID]) {
            [moduleIDs addObject:moduleID];
        } else if (![value boolValue]) {
            [moduleIDs removeObject:moduleID];
        }
        policy.moduleFilterEnabled = YES;
        policy.moduleIDs = [moduleIDs sortedArrayUsingSelector:@selector(compare:)];
    }

    NSError *error = nil;
    if (![self writePolicy:policy error:&error]) {
        LHPresentError(self, error);
        return;
    }
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    LHPreferencePolicy *policy = [self policy];
    if ([key isEqualToString:@"enabled"]) {
        return @(policy.enabled);
    }
    if ([key isEqualToString:@"scope"]) {
        return @(policy.scopeMode);
    }
    if ([key isEqualToString:@"customModules"]) {
        return @(policy.moduleFilterEnabled);
    }
    if ([key hasPrefix:@"module."]) {
        NSNumber *moduleID = @([[key substringFromIndex:[@"module." length]] integerValue]);
        return policy.moduleFilterEnabled ? @([policy.moduleIDs containsObject:moduleID]) : @YES;
    }
    return nil;
}

@end

@interface LHDefaultProfileController : LHPolicyListController
@end

@implementation LHDefaultProfileController

- (NSString *)title {
    return @"Default Profile";
}

- (LHPreferencePolicy *)policy {
    return [self.store defaultPolicy];
}

- (BOOL)writePolicy:(LHPreferencePolicy *)policy error:(NSError **)error {
    return [self.store setDefaultPolicy:policy error:error];
}

@end

@interface LHAppOverrideController : LHPolicyListController
@property (nonatomic, copy) NSString *bundleIdentifier;
@end

@implementation LHAppOverrideController

- (void)viewDidLoad {
    self.bundleIdentifier = [[self specifier] propertyForKey:@"bundleIdentifier"];
    [super viewDidLoad];
}

- (NSString *)title {
    NSString *name = [[self specifier] propertyForKey:@"appName"];
    return [name length] > 0 ? name : self.bundleIdentifier;
}

- (LHPreferencePolicy *)policy {
    NSString *bundleID = self.bundleIdentifier ?: [[self specifier] propertyForKey:@"bundleIdentifier"];
    return [self.store effectivePolicyForBundleIdentifier:bundleID];
}

- (BOOL)writePolicy:(LHPreferencePolicy *)policy error:(NSError **)error {
    NSString *bundleID = self.bundleIdentifier ?: [[self specifier] propertyForKey:@"bundleIdentifier"];
    return [self.store setOverridePolicy:policy forBundleIdentifier:bundleID error:error];
}

- (BOOL)showsOverrideReset {
    NSString *bundleID = self.bundleIdentifier ?: [[self specifier] propertyForKey:@"bundleIdentifier"];
    return [self.store hasOverrideForBundleIdentifier:bundleID];
}

- (void)resetOverride {
    NSError *error = nil;
    NSString *bundleID = self.bundleIdentifier ?: [[self specifier] propertyForKey:@"bundleIdentifier"];
    if (![self.store removeOverrideForBundleIdentifier:bundleID error:&error]) {
        LHPresentError(self, error);
        return;
    }
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (NSMutableArray *)specifiers {
    NSMutableArray *items = [super specifiers];
    if ([items count] > 0 && ![[items firstObject] propertyForKey:@"loupeholeBundleFooter"]) {
        NSString *footer = self.bundleIdentifier ?: @"";
        PSSpecifier *group = [items firstObject];
        [group setProperty:footer forKey:@"footerText"];
        [group setProperty:@YES forKey:@"loupeholeBundleFooter"];
    }
    return items;
}

@end

@interface LHAppOverrideListController : PSListController <UISearchResultsUpdating>
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, id> *> *applications;
@property (nonatomic, copy) NSString *searchText;
@end

@implementation LHAppOverrideListController

- (NSString *)title {
    return @"App Overrides";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.applications = [self loadApplications];
    self.searchText = @"";

    UISearchController *searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    searchController.searchResultsUpdater = self;
    searchController.obscuresBackgroundDuringPresentation = NO;
    if (@available(iOS 11.0, *)) {
        self.navigationItem.searchController = searchController;
        self.navigationItem.hidesSearchBarWhenScrolling = NO;
    } else {
        self.table.tableHeaderView = searchController.searchBar;
    }
}

- (NSArray<NSDictionary<NSString *, id> *> *)loadApplications {
    NSMutableArray<NSDictionary<NSString *, id> *> *apps = [NSMutableArray array];
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    id workspace = [workspaceClass respondsToSelector:@selector(defaultWorkspace)] ? [workspaceClass defaultWorkspace] : nil;
    NSArray *proxies = [workspace respondsToSelector:@selector(allApplications)] ? [workspace allApplications] : @[];
    for (id proxy in proxies) {
        NSString *bundleID = [proxy respondsToSelector:@selector(bundleIdentifier)] ? [proxy bundleIdentifier] : nil;
        NSString *name = [proxy respondsToSelector:@selector(localizedName)] ? [proxy localizedName] : bundleID;
        NSURL *bundleURL = [proxy respondsToSelector:@selector(bundleURL)] ? [proxy bundleURL] : nil;
        if (![self isThirdPartyBundleIdentifier:bundleID bundleURL:bundleURL]) {
            continue;
        }
        UIImage *icon = [self iconForApplicationProxy:proxy];
        [apps addObject:@{
            @"bundleIdentifier": bundleID,
            @"name": [name length] > 0 ? name : bundleID,
            @"icon": icon ?: [self fallbackIcon]
        }];
    }
    return [apps sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *first, NSDictionary *second) {
        BOOL firstOverride = [[LHPreferenceStore sharedStore] hasOverrideForBundleIdentifier:first[@"bundleIdentifier"]];
        BOOL secondOverride = [[LHPreferenceStore sharedStore] hasOverrideForBundleIdentifier:second[@"bundleIdentifier"]];
        if (firstOverride != secondOverride) {
            return firstOverride ? NSOrderedAscending : NSOrderedDescending;
        }
        return [first[@"name"] localizedStandardCompare:second[@"name"]];
    }];
}

- (BOOL)isThirdPartyBundleIdentifier:(NSString *)bundleID bundleURL:(NSURL *)bundleURL {
    if (![bundleID isKindOfClass:[NSString class]] || [bundleID length] == 0) {
        return NO;
    }
    if ([bundleID isEqualToString:@"com.apple"] || [bundleID hasPrefix:@"com.apple."]) {
        return NO;
    }
    NSString *path = [bundleURL path];
    return [path length] == 0 || [path containsString:@".app"];
}

- (UIImage *)iconForApplicationProxy:(id)proxy {
    SEL imageSelector = NSSelectorFromString(@"iconImageForVariant:");
    if ([proxy respondsToSelector:imageSelector]) {
        UIImage *(*imp)(id, SEL, NSInteger) = (UIImage *(*)(id, SEL, NSInteger))[proxy methodForSelector:imageSelector];
        UIImage *image = imp(proxy, imageSelector, 2);
        if ([image isKindOfClass:[UIImage class]]) {
            return image;
        }
    }
    SEL dataSelector = NSSelectorFromString(@"iconDataForVariant:");
    if ([proxy respondsToSelector:dataSelector]) {
        NSData *(*imp)(id, SEL, NSInteger) = (NSData *(*)(id, SEL, NSInteger))[proxy methodForSelector:dataSelector];
        NSData *data = imp(proxy, dataSelector, 2);
        if ([data isKindOfClass:[NSData class]]) {
            UIImage *image = [UIImage imageWithData:data];
            if (image != nil) {
                return image;
            }
        }
    }
    return nil;
}

- (UIImage *)fallbackIcon {
    static UIImage *image;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize size = CGSizeMake(29.0, 29.0);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
        [[UIColor colorWithWhite:0.86 alpha:1.0] setFill];
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height) cornerRadius:6.0];
        [path fill];
        [[UIColor colorWithWhite:0.45 alpha:1.0] setStroke];
        UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(8.0, 8.0, 13.0, 13.0)];
        circle.lineWidth = 2.0;
        [circle stroke];
        image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return image;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.applications = [self loadApplications];
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    self.searchText = searchController.searchBar.text ?: @"";
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *items = [NSMutableArray array];
        [items addObject:LHGroupSpecifier(@"Third Party Apps", @"Rows with overrides are kept at the top.")];
        NSString *query = [self.searchText lowercaseString];
        for (NSDictionary<NSString *, id> *app in self.applications) {
            NSString *name = app[@"name"];
            NSString *bundleID = app[@"bundleIdentifier"];
            if ([query length] > 0 &&
                [[name lowercaseString] rangeOfString:query].location == NSNotFound &&
                [[bundleID lowercaseString] rangeOfString:query].location == NSNotFound) {
                continue;
            }
            NSString *label = [NSString stringWithFormat:@"%@ (%@)", name, bundleID];
            PSSpecifier *specifier = LHLinkSpecifier(label, self, [LHAppOverrideController class], @selector(previewStringForSpecifier:));
            [specifier setProperty:bundleID forKey:@"bundleIdentifier"];
            [specifier setProperty:name forKey:@"appName"];
            [specifier setProperty:app[@"icon"] forKey:@"iconImage"];
            [items addObject:specifier];
        }
        _specifiers = items;
    }
    return _specifiers;
}

- (NSString *)previewStringForSpecifier:(PSSpecifier *)specifier {
    NSString *bundleID = [specifier propertyForKey:@"bundleIdentifier"];
    LHPreferenceStore *store = [LHPreferenceStore sharedStore];
    BOOL override = [store hasOverrideForBundleIdentifier:bundleID];
    LHPreferencePolicy *policy = [store effectivePolicyForBundleIdentifier:bundleID];
    return LHPolicySummary(policy, override);
}

@end

@interface LHDebugController : PSListController
@end

@implementation LHDebugController

- (NSString *)title {
    return @"Debug";
}

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        LHPreferenceStore *store = [LHPreferenceStore sharedStore];
        _specifiers = [@[
            LHGroupSpecifier(@"Seeds", nil),
            LHValueSpecifier(@"Build seed", [store buildSeedString]),
            LHValueSpecifier(@"Root seed", [store rootSeedHexString]),
            LHGroupSpecifier(@"Paths", @"Paths are derived from generated package names at runtime."),
            LHValueSpecifier(@"Policy", [store policyPath]),
            LHValueSpecifier(@"Filter", [store filterPath]),
            LHValueSpecifier(@"Support", [store supportDirectoryPath]),
            LHValueSpecifier(@"Preferences", [store preferencesDirectoryPath]),
            LHValueSpecifier(@"Caches", [store cacheDirectoryPath])
        ] mutableCopy];
    }
    return _specifiers;
}

@end

@interface LHRootListController : PSListController
@end

@implementation LHRootListController

- (NSString *)title {
    return @"Loupehole";
}

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [@[
            LHGroupSpecifier(@"Configuration", nil),
            LHLinkSpecifier(@"Default Profile", self, [LHDefaultProfileController class], @selector(defaultPreviewForSpecifier:)),
            LHLinkSpecifier(@"App Overrides", self, [LHAppOverrideListController class], nil),
            LHButtonSpecifier(@"Export Settings", self, @selector(exportSettings)),
            LHGroupSpecifier(@"Reset", nil),
            LHButtonSpecifier(@"Reset Configuration", self, @selector(confirmResetAll)),
            LHGroupSpecifier(@"Diagnostics", nil),
            LHLinkSpecifier(@"Debug", self, [LHDebugController class], nil)
        ] mutableCopy];
    }
    return _specifiers;
}

- (NSString *)defaultPreviewForSpecifier:(PSSpecifier *)specifier {
    (void)specifier;
    LHPreferencePolicy *policy = [[LHPreferenceStore sharedStore] defaultPolicy];
    return policy.enabled ? @"On" : @"Off";
}

- (void)confirmResetAll {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset Configuration"
                                                                   message:@"Default profile and all app overrides will return to the package defaults."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        NSError *error = nil;
        if (![[LHPreferenceStore sharedStore] resetAllWithError:&error]) {
            LHPresentError(self, error);
            return;
        }
        _specifiers = nil;
        [self reloadSpecifiers];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)exportSettings {
    NSError *error = nil;
    NSURL *url = [[LHPreferenceStore sharedStore] exportSettingsWithError:&error];
    if (url == nil) {
        LHPresentError(self, error);
        return;
    }
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    activity.popoverPresentationController.sourceView = self.view;
    [self presentViewController:activity animated:YES completion:nil];
}

@end
