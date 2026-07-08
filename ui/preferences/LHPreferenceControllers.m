#import "LHPreferenceStore.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIImage+Private.h>
#import <MobileCoreServices/LSApplicationProxy.h>
#import <MobileCoreServices/LSApplicationWorkspace.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>

@interface PSSpecifier (LoupeholeValues)
@property (nonatomic, retain) NSArray *values;
@property (nonatomic, retain) NSArray *titles;
@end

@interface PSSpecifier (LoupeholeTarget)
- (id)target;
@end

static const NSInteger LHCustomSeedScopeMode = 3;

/** Builds the short enabled/scope/modules summary shown in policy rows. */
static NSString *LHPolicySummary(LHPreferencePolicy *policy, BOOL override) {
    NSString *state = policy.enabled ? @"On" : @"Off";
    if (override) {
        return [NSString stringWithFormat:@"Override: %@", state];
    }
    return [NSString stringWithFormat:@"Default: %@", state];
}

/** Returns installed application display names keyed by bundle identifier. */
static NSDictionary<NSString *, NSString *> *LHApplicationNamesByBundleIdentifier(void) {
    NSMutableDictionary<NSString *, NSString *> *names = [NSMutableDictionary dictionary];
    Class workspaceClass = NSClassFromString(@"LSApplicationWorkspace");
    id workspace = [workspaceClass respondsToSelector:@selector(defaultWorkspace)] ? [workspaceClass defaultWorkspace] : nil;
    NSArray *proxies = [workspace respondsToSelector:@selector(allApplications)] ? [workspace allApplications] : @[];
    for (id proxy in proxies) {
        NSString *bundleID = [proxy respondsToSelector:@selector(bundleIdentifier)] ? [proxy bundleIdentifier] : nil;
        NSString *name = [proxy respondsToSelector:@selector(localizedName)] ? [proxy localizedName] : bundleID;
        if ([bundleID length] > 0 && [name length] > 0) {
            names[bundleID] = name;
        }
    }
    return names;
}

/** Presents a simple alert for a preference-store error. */
static void LHPresentError(UIViewController *controller, NSError *error) {
    NSString *message = error.localizedDescription ?: @"The settings could not be updated.";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Loupehole" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [controller presentViewController:alert animated:YES completion:nil];
}

/** Creates a grouped Preferences section specifier. */
static PSSpecifier *LHGroupSpecifier(NSString *label, NSString *footer) {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:label target:nil set:nil get:nil detail:nil cell:PSGroupCell edit:nil];
    if (footer != nil) {
        [specifier setProperty:footer forKey:@"footerText"];
    }
    return specifier;
}

/** Creates a switch specifier backed by a preference key. */
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

/** Creates a plain action-button specifier. */
static PSSpecifier *LHButtonSpecifier(NSString *label, id target, SEL action) {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:label target:target set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    specifier.buttonAction = action;
    return specifier;
}

/** Creates a destructive action-button specifier. */
static PSSpecifier *LHDestructiveButtonSpecifier(NSString *label, id target, SEL action) {
    PSSpecifier *specifier = LHButtonSpecifier(label, target, action);
    [specifier setProperty:NSClassFromString(@"LHDestructiveButtonCell") forKey:@"cellClass"];
    [specifier setProperty:@60.0 forKey:@"height"];
    return specifier;
}

/** Creates a navigation-link specifier with an optional preview selector. */
static PSSpecifier *LHLinkSpecifier(NSString *label, id target, Class detail, SEL preview) {
    return [PSSpecifier preferenceSpecifierNamed:label target:target set:nil get:preview detail:detail cell:PSLinkListCell edit:nil];
}

/** Calculates enough row height for a wrapped value string. */
static CGFloat LHValueHeightForValue(NSString *value) {
    NSUInteger length = [(value ?: @"") length];
    if (length > 150) {
        return 144.0;
    }
    if (length > 90) {
        return 116.0;
    }
    if (length > 48) {
        return 88.0;
    }
    return 60.0;
}

/** Creates a read-only value specifier using the wrapping value cell. */
static PSSpecifier *LHValueSpecifier(NSString *label, NSString *value) {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:label target:nil set:nil get:nil detail:nil cell:PSTitleValueCell edit:nil];
    [specifier setProperty:value ?: @"" forKey:@"value"];
    [specifier setProperty:NSClassFromString(@"LHValueTableCell") forKey:@"cellClass"];
    [specifier setProperty:@(LHValueHeightForValue(value)) forKey:@"height"];
    return specifier;
}

@interface LHValueTableCell : PSTableCell <UIContextMenuInteractionDelegate>
@property (nonatomic, copy) NSString *lhCopyValue;
@end

@implementation LHValueTableCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.textLabel.text = specifier.name;
        self.textLabel.numberOfLines = 1;
        self.lhCopyValue = [specifier propertyForKey:@"value"] ?: @"";
        self.detailTextLabel.text = self.lhCopyValue;
        self.detailTextLabel.numberOfLines = 0;
        self.detailTextLabel.lineBreakMode = NSLineBreakByCharWrapping;
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self.contentView addInteraction:[[UIContextMenuInteraction alloc] initWithDelegate:self]];
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    self.textLabel.text = specifier.name;
    self.lhCopyValue = [specifier propertyForKey:@"value"] ?: @"";
    self.detailTextLabel.text = self.lhCopyValue;
}

+ (CGFloat)preferredHeightForSpecifier:(PSSpecifier *)specifier {
    NSString *value = [specifier propertyForKey:@"value"] ?: @"";
    return LHValueHeightForValue(value);
}

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location {
    (void)interaction;
    (void)location;

    NSString *copyValue = [self.lhCopyValue copy];
    if ([copyValue length] == 0) {
        return nil;
    }

    return [UIContextMenuConfiguration configurationWithIdentifier:nil
                                                   previewProvider:nil
                                                    actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> *suggestedActions) {
        (void)suggestedActions;
        UIAction *copyAction = [UIAction actionWithTitle:@"Copy" image:nil identifier:nil handler:^(__unused UIAction *action) {
            [UIPasteboard generalPasteboard].string = copyValue;
        }];
        return [UIMenu menuWithTitle:@"" children:@[copyAction]];
    }];
}

@end

@interface LHStaticValueTableCell : LHValueTableCell
@end

@implementation LHStaticValueTableCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:NO animated:animated];
}

@end

/** Creates a read-only static value specifier. */
static PSSpecifier *LHStaticValueSpecifier(NSString *label, NSString *value) {
    PSSpecifier *specifier = LHValueSpecifier(label, value);
    [specifier setProperty:NSClassFromString(@"LHStaticValueTableCell") forKey:@"cellClass"];
    return specifier;
}

@interface LHDestructiveButtonCell : PSTableCell
@end

@implementation LHDestructiveButtonCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.textLabel.text = specifier.name;
        self.textLabel.textAlignment = NSTextAlignmentCenter;
        self.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        self.textLabel.adjustsFontForContentSizeCategory = YES;
        self.textLabel.textColor = [UIColor systemRedColor] ?: [UIColor redColor];
    }
    return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    self.textLabel.text = specifier.name;
    self.textLabel.textAlignment = NSTextAlignmentCenter;
    self.textLabel.textColor = [UIColor systemRedColor] ?: [UIColor redColor];
}

+ (CGFloat)preferredHeightForSpecifier:(PSSpecifier *)specifier {
    (void)specifier;
    return 60.0;
}

@end

@interface LHAppOverrideCell : PSTableCell
@property (nonatomic, strong) UIImageView *lhIconView;
@property (nonatomic, strong) UILabel *lhTitleLabel;
@property (nonatomic, strong) UILabel *lhSubtitleLabel;
@property (nonatomic, strong) UILabel *lhPreviewLabel;
@end

@implementation LHAppOverrideCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.textLabel.hidden = YES;
        self.detailTextLabel.hidden = YES;

        _lhIconView = [[UIImageView alloc] initWithImage:[specifier propertyForKey:@"LHIconImage"]];
        _lhIconView.contentMode = UIViewContentModeScaleAspectFit;
        _lhIconView.layer.cornerRadius = 8.0;
        _lhIconView.layer.masksToBounds = YES;
        [self.contentView addSubview:_lhIconView];

        _lhTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _lhTitleLabel.text = specifier.name;
        _lhTitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        _lhTitleLabel.adjustsFontForContentSizeCategory = YES;
        _lhTitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_lhTitleLabel];

        _lhSubtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _lhSubtitleLabel.text = [specifier propertyForKey:@"subtitle"] ?: @"";
        _lhSubtitleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        _lhSubtitleLabel.textColor = [UIColor secondaryLabelColor] ?: [UIColor grayColor];
        _lhSubtitleLabel.adjustsFontForContentSizeCategory = YES;
        _lhSubtitleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_lhSubtitleLabel];

        _lhPreviewLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _lhPreviewLabel.text = [specifier propertyForKey:@"preview"] ?: @"";
        _lhPreviewLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        _lhPreviewLabel.textColor = [UIColor secondaryLabelColor] ?: [UIColor grayColor];
        _lhPreviewLabel.adjustsFontForContentSizeCategory = YES;
        _lhPreviewLabel.textAlignment = NSTextAlignmentLeft;
        _lhPreviewLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_lhPreviewLabel];
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat iconSide = 40.0;
    CGFloat left = 15.0;
    CGFloat midY = CGRectGetMidY(self.contentView.bounds);
    self.lhIconView.frame = CGRectMake(left, midY - iconSide / 2.0, iconSide, iconSide);

    CGFloat textLeft = CGRectGetMaxX(self.lhIconView.frame) + 12.0;
    CGFloat rightInset = 32.0;
    CGFloat availableWidth = CGRectGetWidth(self.contentView.bounds) - textLeft - rightInset;
    if (availableWidth < 90.0) {
        availableWidth = CGRectGetWidth(self.contentView.bounds) - textLeft - 12.0;
    }

    self.lhTitleLabel.frame = CGRectMake(textLeft, 8.0, availableWidth, 22.0);
    self.lhSubtitleLabel.frame = CGRectMake(textLeft, 31.0, availableWidth, 19.0);
    self.lhPreviewLabel.frame = CGRectMake(textLeft, 52.0, availableWidth, 18.0);
}

+ (CGFloat)preferredHeightForSpecifier:(PSSpecifier *)specifier {
    (void)specifier;
    return 82.0;
}

@end

@interface LHScopeOptionCell : PSTableCell
@end

@implementation LHScopeOptionCell

- (void)applyScopeSpecifier:(PSSpecifier *)specifier {
    self.textLabel.text = specifier.name;
    self.textLabel.numberOfLines = 1;
    self.detailTextLabel.text = [specifier propertyForKey:@"subtitle"] ?: @"";
    self.detailTextLabel.numberOfLines = 2;
    self.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    BOOL checked = [[specifier propertyForKey:@"checked"] boolValue];
    if ([self respondsToSelector:@selector(setChecked:)]) {
        [self setChecked:checked];
    }
    self.accessoryType = checked ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        [self applyScopeSpecifier:specifier];
    }
    return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    [self applyScopeSpecifier:specifier];
}

+ (CGFloat)preferredHeightForSpecifier:(PSSpecifier *)specifier {
    (void)specifier;
    return 74.0;
}

@end

@interface LHCustomSeedCell : PSTableCell
@property (nonatomic, strong) UITextField *lhTextField;
@property (nonatomic, strong) UIButton *lhRandomButton;
@end

@implementation LHCustomSeedCell

- (id)targetForSpecifier:(PSSpecifier *)specifier {
    return [[specifier propertyForKey:@"targetController"] nonretainedObjectValue];
}

- (void)configureWithSpecifier:(PSSpecifier *)specifier {
    self.textLabel.hidden = YES;
    self.detailTextLabel.hidden = YES;
    self.selectionStyle = UITableViewCellSelectionStyleNone;

    id target = [self targetForSpecifier:specifier];
    if (self.lhTextField == nil) {
        self.lhTextField = [[UITextField alloc] initWithFrame:CGRectZero];
        self.lhTextField.borderStyle = UITextBorderStyleRoundedRect;
        self.lhTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.lhTextField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.lhTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
        self.lhTextField.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        self.lhTextField.adjustsFontForContentSizeCategory = YES;
        self.lhTextField.placeholder = @"UUID seed";
        [self.contentView addSubview:self.lhTextField];
    }
    [self.lhTextField removeTarget:nil action:NULL forControlEvents:UIControlEventEditingChanged | UIControlEventEditingDidEnd];
    [self.lhTextField addTarget:target action:@selector(customSeedTextChanged:) forControlEvents:UIControlEventEditingChanged];
    [self.lhTextField addTarget:target action:@selector(customSeedEditingDidEnd:) forControlEvents:UIControlEventEditingDidEnd];
    if (![self.lhTextField isFirstResponder]) {
        self.lhTextField.text = [specifier propertyForKey:@"customSeed"] ?: @"";
    }

    if (self.lhRandomButton == nil) {
        self.lhRandomButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.lhRandomButton setTitle:@"Random" forState:UIControlStateNormal];
        self.lhRandomButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCallout];
        self.lhRandomButton.titleLabel.adjustsFontForContentSizeCategory = YES;
        [self.contentView addSubview:self.lhRandomButton];
    }
    [self.lhRandomButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [self.lhRandomButton addTarget:target action:@selector(randomizeCustomSeed) forControlEvents:UIControlEventTouchUpInside];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        [self configureWithSpecifier:specifier];
    }
    return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    [self configureWithSpecifier:specifier];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat inset = 15.0;
    CGFloat buttonWidth = 84.0;
    CGFloat gap = 10.0;
    CGFloat height = 36.0;
    CGFloat y = (CGRectGetHeight(self.contentView.bounds) - height) / 2.0;
    CGFloat width = CGRectGetWidth(self.contentView.bounds) - inset * 2.0;
    self.lhRandomButton.frame = CGRectMake(CGRectGetMaxX(self.contentView.bounds) - inset - buttonWidth, y, buttonWidth, height);
    self.lhTextField.frame = CGRectMake(inset, y, width - buttonWidth - gap, height);
}

+ (CGFloat)preferredHeightForSpecifier:(PSSpecifier *)specifier {
    (void)specifier;
    return 64.0;
}

@end

@interface LHSeedAssociationCell : PSTableCell
@end

@implementation LHSeedAssociationCell

- (void)applySeedSpecifier:(PSSpecifier *)specifier {
    self.textLabel.text = specifier.name;
    self.textLabel.numberOfLines = 1;
    self.textLabel.font = [UIFont monospacedSystemFontOfSize:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote].pointSize weight:UIFontWeightRegular];
    self.detailTextLabel.text = [specifier propertyForKey:@"associatedApps"] ?: @"";
    self.detailTextLabel.numberOfLines = 0;
    self.detailTextLabel.lineBreakMode = NSLineBreakByWordWrapping;
    BOOL selectedSeed = [[specifier propertyForKey:@"selectedSeed"] boolValue];
    self.accessoryType = selectedSeed ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    self.selectionStyle = UITableViewCellSelectionStyleDefault;
    self.userInteractionEnabled = YES;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        [self applySeedSpecifier:specifier];
    }
    return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    [self applySeedSpecifier:specifier];
}

+ (CGFloat)preferredHeightForSpecifier:(PSSpecifier *)specifier {
    NSNumber *count = [specifier propertyForKey:@"associatedAppCount"];
    return 58.0 + MAX(1, [count integerValue]) * 38.0;
}

@end

@class LHScopeSelectionController;

@interface LHPolicyListController : PSListController
@property (nonatomic, readonly) LHPreferenceStore *store;
- (LHPreferencePolicy *)policy;
- (BOOL)writePolicy:(LHPreferencePolicy *)policy error:(NSError **)error;
- (BOOL)showsOverrideReset;
- (void)resetOverride;
- (NSString *)moduleKeyForID:(NSNumber *)moduleID;
- (NSString *)scopeSelectionBundleIdentifier;
- (NSString *)scopeSelectionAppName;
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

- (NSString *)scopeSelectionBundleIdentifier {
    return nil;
}

- (NSString *)scopeSelectionAppName {
    return nil;
}

- (PSSpecifier *)scopeSpecifier {
    LHPreferencePolicy *policy = [self policy];
    PSSpecifier *specifier = LHLinkSpecifier(@"Scope", self, NSClassFromString(@"LHScopeSelectionController"), @selector(scopePreviewForSpecifier:));
    [specifier setProperty:@"scope" forKey:@"key"];
    [specifier setProperty:@(policy.scopeMode) forKey:@"scopeMode"];
    NSString *bundleID = [self scopeSelectionBundleIdentifier];
    NSString *appName = [self scopeSelectionAppName];
    if ([bundleID length] > 0) {
        [specifier setProperty:bundleID forKey:@"bundleIdentifier"];
    }
    if ([appName length] > 0) {
        [specifier setProperty:appName forKey:@"appName"];
    }
    return specifier;
}

- (NSString *)scopePreviewForSpecifier:(PSSpecifier *)specifier {
    (void)specifier;
    return [LHPreferenceStore scopeLabelForMode:[self policy].scopeMode];
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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _specifiers = nil;
    [self reloadSpecifiers];
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
    policy.scopeMode = (policy.scopeMode + 1) % (LHCustomSeedScopeMode + 1);
    if (policy.scopeMode == LHCustomSeedScopeMode && ![LHPreferenceStore isValidSeedString:policy.customSeed]) {
        policy.customSeed = [LHPreferenceStore randomSeedString];
    }
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

@interface LHScopeSelectionController : PSListController
@property (nonatomic, strong) LHPreferencePolicy *entryPolicy;
@property (nonatomic, copy) NSString *draftCustomSeed;
@property (nonatomic, copy) NSString *scopeBundleIdentifier;
@property (nonatomic, copy) NSString *scopeAppName;
@end

@implementation LHScopeSelectionController

- (void)setSpecifier:(PSSpecifier *)specifier {
    [super setSpecifier:specifier];
    [self updateScopeContextFromSpecifier:specifier];
}

- (void)updateScopeContextFromSpecifier:(PSSpecifier *)specifier {
    if (specifier == nil) {
        return;
    }

    NSString *bundleID = [specifier propertyForKey:@"bundleIdentifier"];
    NSString *appName = [specifier propertyForKey:@"appName"];

    if ([bundleID length] > 0) {
        self.scopeBundleIdentifier = bundleID;
    }
    if ([appName length] > 0) {
        self.scopeAppName = appName;
    }

    id linkTarget = [specifier target];
    if ([linkTarget isKindOfClass:[LHPolicyListController class]]) {
        LHPolicyListController *policyController = (LHPolicyListController *)linkTarget;
        if ([self.scopeBundleIdentifier length] == 0) {
            self.scopeBundleIdentifier = [policyController scopeSelectionBundleIdentifier];
        }
        if ([self.scopeAppName length] == 0) {
            self.scopeAppName = [policyController scopeSelectionAppName];
        }
    }
}

- (void)resolveScopeContext {
    [self updateScopeContextFromSpecifier:[self specifier]];
}

- (NSString *)scopeTitle {
    [self resolveScopeContext];

    if ([self.scopeBundleIdentifier length] == 0) {
        return @"Default Scope";
    }

    if ([self.scopeAppName length] > 0) {
        return [NSString stringWithFormat:@"%@ (%@)",
                                          self.scopeAppName,
                                          self.scopeBundleIdentifier];
    }

    return self.scopeBundleIdentifier;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self resolveScopeContext];
    self.navigationItem.title = [self scopeTitle];
    self.entryPolicy = [[self policy] copy];
    self.draftCustomSeed = self.entryPolicy.customSeed ?: @"";
}

- (NSString *)title {
    return [self scopeTitle];
}

- (LHPreferencePolicy *)policy {
    LHPreferenceStore *store = [LHPreferenceStore sharedStore];
    NSString *bundleID = [self bundleIdentifier];
    if ([bundleID length] > 0) {
        return [store effectivePolicyForBundleIdentifier:bundleID];
    }
    return [store defaultPolicy];
}

- (BOOL)writePolicy:(LHPreferencePolicy *)policy error:(NSError **)error {
    LHPreferenceStore *store = [LHPreferenceStore sharedStore];
    NSString *bundleID = [self bundleIdentifier];
    if ([bundleID length] > 0) {
        return [store setOverridePolicy:policy forBundleIdentifier:bundleID error:error];
    }
    return [store setDefaultPolicy:policy error:error];
}

- (NSString *)bundleIdentifier {
    [self resolveScopeContext];
    return self.scopeBundleIdentifier;
}

- (NSArray<NSString *> *)bundleIdentifiersUsingSeed:(NSString *)seed {
    NSString *normalizedSeed = [LHPreferenceStore normalizedSeedString:seed];
    if (normalizedSeed == nil) {
        return @[];
    }

    NSString *currentBundle = [self bundleIdentifier];
    NSDictionary<NSString *, LHPreferencePolicy *> *overrides = [[LHPreferenceStore sharedStore] overridePolicies];
    NSMutableArray<NSString *> *bundleIDs = [NSMutableArray array];
    for (NSString *bundleID in [[overrides allKeys] sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
        LHPreferencePolicy *policy = overrides[bundleID];
        if ([bundleID isEqualToString:currentBundle]) {
            continue;
        }
        if (policy.scopeMode == LHCustomSeedScopeMode &&
            [[LHPreferenceStore normalizedSeedString:policy.customSeed] isEqualToString:normalizedSeed]) {
            [bundleIDs addObject:bundleID];
        }
    }
    return bundleIDs;
}

- (PSSpecifier *)customSeedSpecifierForPolicy:(LHPreferencePolicy *)policy {
    PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:@"Custom Seed"
                                                            target:self
                                                               set:nil
                                                               get:nil
                                                            detail:nil
                                                              cell:PSTitleValueCell
                                                              edit:nil];
    [specifier setProperty:NSClassFromString(@"LHCustomSeedCell") forKey:@"cellClass"];
    [specifier setProperty:@64.0 forKey:@"height"];
    [specifier setProperty:[NSValue valueWithNonretainedObject:self] forKey:@"targetController"];
    [specifier setProperty:self.draftCustomSeed ?: policy.customSeed ?: @"" forKey:@"customSeed"];
    return specifier;
}

- (NSString *)selectedSeedPreviewForSpecifier:(PSSpecifier *)specifier {
    (void)specifier;

    NSString *seed = [LHPreferenceStore normalizedSeedString:
        self.draftCustomSeed ?: [self policy].customSeed];

    if (seed == nil) {
        return @"None";
    }

    // bundleIdentifiersUsingSeed: intentionally excludes the current app.
    NSUInteger otherAppCount = [[self bundleIdentifiersUsingSeed:seed] count];
    NSUInteger totalAppCount = otherAppCount;

    return [NSString stringWithFormat:@"matches %lu %@",
            (unsigned long)totalAppCount,
            totalAppCount == 1 ? @"app" : @"apps"];
}

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *items = [NSMutableArray array];
        [items addObject:LHGroupSpecifier(@"Scope", @"Scope controls which apps share the same generated replacement values.")];
        LHPreferencePolicy *policy = [self policy];
        NSInteger currentMode = policy.scopeMode;
        for (NSInteger mode = 0; mode <= LHCustomSeedScopeMode; mode++) {
            NSString *label = [LHPreferenceStore scopeLabelForMode:mode];
            PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:label
                                                                    target:self
                                                                       set:nil
                                                                       get:nil
                                                                    detail:nil
                                                                      cell:PSListItemCell
                                                                      edit:nil];
            [specifier setProperty:@(mode) forKey:@"scopeMode"];
            [specifier setProperty:[LHPreferenceStore scopeDescriptionForMode:mode] forKey:@"subtitle"];
            [specifier setProperty:@(mode == currentMode) forKey:@"checked"];
            [specifier setProperty:NSClassFromString(@"LHScopeOptionCell") forKey:@"cellClass"];
            [specifier setProperty:@74.0 forKey:@"height"];
            [specifier setProperty:@YES forKey:@"enabled"];
            [items addObject:specifier];
        }
        if (currentMode == LHCustomSeedScopeMode) {
            [items addObject:LHGroupSpecifier(@"Custom Seed", @"The UUID seed below replaces the package root seed for this scope.")];
            [items addObject:[self customSeedSpecifierForPolicy:policy]];
            if ([[self bundleIdentifier] length] > 0) {
                PSSpecifier *choose = LHLinkSpecifier(@"Choose Existing Seed", self, NSClassFromString(@"LHCustomSeedListController"), @selector(selectedSeedPreviewForSpecifier:));
                [choose setProperty:[self bundleIdentifier] forKey:@"bundleIdentifier"];
                if ([self.scopeAppName length] > 0) {
                    [choose setProperty:self.scopeAppName forKey:@"appName"];
                }
                [items addObject:choose];
            }
        }
        _specifiers = items;
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self resolveScopeContext];
    self.navigationItem.title = [self scopeTitle];
    self.draftCustomSeed = [self policy].customSeed ?: self.draftCustomSeed ?: @"";
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.isMovingFromParentViewController || self.navigationController.isBeingDismissed) {
        [self commitCustomSeedBeforeLeaving];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
    if ([specifier propertyForKey:@"scopeMode"] != nil) {
        [self selectScope:specifier];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (void)selectScope:(PSSpecifier *)specifier {
    LHPreferencePolicy *policy = [[self policy] copy];
    policy.scopeMode = [[specifier propertyForKey:@"scopeMode"] integerValue];
    if (policy.scopeMode == LHCustomSeedScopeMode) {
        NSString *seed = [LHPreferenceStore normalizedSeedString:self.draftCustomSeed ?: policy.customSeed];
        if (seed == nil) {
            seed = [LHPreferenceStore randomSeedString];
        }
        policy.customSeed = seed;
        self.draftCustomSeed = seed;
    }
    NSError *error = nil;
    if (![self writePolicy:policy error:&error]) {
        LHPresentError(self, error);
        return;
    }
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (void)customSeedTextChanged:(UITextField *)textField {
    self.draftCustomSeed = textField.text ?: @"";
}

- (void)customSeedEditingDidEnd:(UITextField *)textField {
    self.draftCustomSeed = textField.text ?: @"";
    NSString *seed = [LHPreferenceStore normalizedSeedString:self.draftCustomSeed];
    if (seed == nil) {
        return;
    }
    [self applyCustomSeed:seed updateAssociatedBundles:NO];
}

- (void)commitCustomSeedBeforeLeaving {
    LHPreferencePolicy *policy = [self policy];
    if (policy.scopeMode != LHCustomSeedScopeMode) {
        return;
    }

    NSString *seed = [LHPreferenceStore normalizedSeedString:self.draftCustomSeed];
    if (seed != nil) {
        [self applyCustomSeed:seed updateAssociatedBundles:NO];
        return;
    }

    NSError *writeError = nil;
    [self writePolicy:self.entryPolicy error:&writeError];
    UIViewController *presenter = self.navigationController.topViewController ?: self.navigationController;
    dispatch_async(dispatch_get_main_queue(), ^{
        LHPresentError(presenter, [NSError errorWithDomain:@"com.loupehole.preferences"
                                                      code:1
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Custom seed must be a UUID. The previous scope settings were restored."}]);
    });
}

- (void)applyCustomSeed:(NSString *)seed updateAssociatedBundles:(BOOL)updateAssociatedBundles {
    NSString *normalizedSeed = [LHPreferenceStore normalizedSeedString:seed];
    if (normalizedSeed == nil) {
        LHPresentError(self, [NSError errorWithDomain:@"com.loupehole.preferences"
                                                code:1
                                            userInfo:@{NSLocalizedDescriptionKey: @"Custom seed must be a UUID."}]);
        return;
    }

    NSError *error = nil;
    NSString *currentBundle = [self bundleIdentifier];
    if (updateAssociatedBundles && [currentBundle length] > 0) {
        NSString *oldSeed = [LHPreferenceStore normalizedSeedString:self.draftCustomSeed ?: [self policy].customSeed];
        if (oldSeed != nil && ![[LHPreferenceStore sharedStore] replaceCustomSeed:oldSeed withSeed:normalizedSeed includingBundleIdentifier:currentBundle error:&error]) {
            LHPresentError(self, error);
            return;
        }
    } else {
        LHPreferencePolicy *policy = [[self policy] copy];
        policy.scopeMode = LHCustomSeedScopeMode;
        policy.customSeed = normalizedSeed;
        if (![self writePolicy:policy error:&error]) {
            LHPresentError(self, error);
            return;
        }
    }

    self.draftCustomSeed = normalizedSeed;
    _specifiers = nil;
    [self reloadSpecifiers];
}

- (void)randomizeCustomSeed {
    NSString *newSeed = [LHPreferenceStore randomSeedString];
    NSString *currentSeed = [LHPreferenceStore normalizedSeedString:self.draftCustomSeed ?: [self policy].customSeed];
    NSArray<NSString *> *associatedBundles = [self bundleIdentifiersUsingSeed:currentSeed];
    if ([[self bundleIdentifier] length] > 0 && [associatedBundles count] > 0) {
        NSString *message = [NSString stringWithFormat:@"This seed is also used by %lu other app%@.",
                             (unsigned long)[associatedBundles count],
                             [associatedBundles count] == 1 ? @"" : @"s"];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Randomize Seed"
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Only This App" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self applyCustomSeed:newSeed updateAssociatedBundles:NO];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"All Apps Using This Seed" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            [self applyCustomSeed:newSeed updateAssociatedBundles:YES];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    [self applyCustomSeed:newSeed updateAssociatedBundles:NO];
}

@end

@interface LHCustomSeedListController : PSListController
@end

@implementation LHCustomSeedListController

- (NSString *)title {
    return @"Existing Seeds";
}

- (NSString *)bundleIdentifier {
    return [[self specifier] propertyForKey:@"bundleIdentifier"];
}

- (NSString *)currentSelectedSeed {
    NSString *bundleID = [self bundleIdentifier];
    if ([bundleID length] == 0) {
        return nil;
    }

    LHPreferencePolicy *policy = [[LHPreferenceStore sharedStore] effectivePolicyForBundleIdentifier:bundleID];
    if (policy.scopeMode != LHCustomSeedScopeMode) {
        return nil;
    }

    return [LHPreferenceStore normalizedSeedString:policy.customSeed];
}

- (NSArray<NSDictionary<NSString *, id> *> *)seedAssociations {
    NSString *currentBundle = [self bundleIdentifier];
    NSDictionary<NSString *, NSString *> *appNames = LHApplicationNamesByBundleIdentifier();
    NSDictionary<NSString *, LHPreferencePolicy *> *overrides = [[LHPreferenceStore sharedStore] overridePolicies];
    NSMutableDictionary<NSString *, NSMutableArray<NSDictionary<NSString *, NSString *> *> *> *groups = [NSMutableDictionary dictionary];
    for (NSString *bundleID in [[overrides allKeys] sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
        if ([bundleID isEqualToString:currentBundle]) {
            continue;
        }
        LHPreferencePolicy *policy = overrides[bundleID];
        NSString *seed = [LHPreferenceStore normalizedSeedString:policy.customSeed];
        if (policy.scopeMode != LHCustomSeedScopeMode || seed == nil) {
            continue;
        }
        NSMutableArray *apps = groups[seed];
        if (apps == nil) {
            apps = [NSMutableArray array];
            groups[seed] = apps;
        }
        NSString *name = appNames[bundleID] ?: bundleID;
        [apps addObject:@{@"name": name, @"bundleIdentifier": bundleID}];
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *items = [NSMutableArray array];
    for (NSString *seed in [[groups allKeys] sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
        NSArray *apps = groups[seed];
        [items addObject:@{@"seed": seed, @"apps": apps}];
    }
    return items;
}

- (NSString *)associatedAppsText:(NSArray<NSDictionary<NSString *, NSString *> *> *)apps {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSDictionary<NSString *, NSString *> *app in apps) {
        [lines addObject:[NSString stringWithFormat:@"%@ (%@)", app[@"name"] ?: @"Unknown", app[@"bundleIdentifier"] ?: @""]];
    }
    return [lines componentsJoinedByString:@"\n"];
}

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *items = [NSMutableArray array];
        NSArray<NSDictionary<NSString *, id> *> *associations = [self seedAssociations];
        NSString *selectedSeed = [self currentSelectedSeed];
        [items addObject:LHGroupSpecifier(@"Seeds", [associations count] == 0 ? @"No other app override uses a custom seed yet." : @"A checkmark marks the seed currently used by this app. Selecting a seed copies it into this app override.")];
        for (NSDictionary<NSString *, id> *association in associations) {
            NSString *seed = association[@"seed"];
            NSArray *apps = association[@"apps"] ?: @[];
            PSSpecifier *specifier = [PSSpecifier preferenceSpecifierNamed:seed
                                                                    target:self
                                                                       set:nil
                                                                       get:nil
                                                                    detail:nil
                                                                      cell:PSListItemCell
                                                                      edit:nil];
            [specifier setProperty:@YES forKey:@"enabled"];
            [specifier setProperty:seed forKey:@"customSeed"];
            [specifier setProperty:@([seed isEqualToString:selectedSeed]) forKey:@"selectedSeed"];
            [specifier setProperty:[self associatedAppsText:apps] forKey:@"associatedApps"];
            [specifier setProperty:@([apps count]) forKey:@"associatedAppCount"];
            [specifier setProperty:NSClassFromString(@"LHSeedAssociationCell") forKey:@"cellClass"];
            [specifier setProperty:@([LHSeedAssociationCell preferredHeightForSpecifier:specifier]) forKey:@"height"];
            [items addObject:specifier];
        }
        _specifiers = items;
    }
    return _specifiers;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    PSSpecifier *specifier = [self specifierAtIndexPath:indexPath];
    NSString *seed = [specifier propertyForKey:@"customSeed"];
    if ([LHPreferenceStore isValidSeedString:seed]) {
        LHPreferenceStore *store = [LHPreferenceStore sharedStore];
        NSString *bundleID = [self bundleIdentifier];
        LHPreferencePolicy *policy = [[store effectivePolicyForBundleIdentifier:bundleID] copy];
        policy.scopeMode = LHCustomSeedScopeMode;
        policy.customSeed = [LHPreferenceStore normalizedSeedString:seed];
        NSError *error = nil;
        if (![store setOverridePolicy:policy forBundleIdentifier:bundleID error:&error]) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            LHPresentError(self, error);
            return;
        }
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
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

- (NSString *)scopeSelectionBundleIdentifier {
    return self.bundleIdentifier ?: [[self specifier] propertyForKey:@"bundleIdentifier"];
}

- (NSString *)scopeSelectionAppName {
    return [[self specifier] propertyForKey:@"appName"];
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
    if ([items count] == 0 ||
        [[[items firstObject] propertyForKey:@"loupeholeAppInfoSection"] boolValue]) {
        return items;
    }

    NSString *bundleID = [self scopeSelectionBundleIdentifier] ?: @"";
    NSString *appName = [self scopeSelectionAppName];
    if ([appName length] == 0) {
        appName = [bundleID length] > 0 ? bundleID : @"Unknown App";
    }

    PSSpecifier *infoGroup = LHGroupSpecifier(@"Info", nil);
    [infoGroup setProperty:@YES forKey:@"loupeholeAppInfoSection"];

    [items insertObject:infoGroup atIndex:0];
    [items insertObject:LHStaticValueSpecifier(@"App Name", appName) atIndex:1];
    [items insertObject:LHStaticValueSpecifier(@"Bundle Identifier", bundleID) atIndex:2];

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
    self.navigationItem.searchController = searchController;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
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
        UIImage *icon = [self iconForApplicationProxy:proxy bundleIdentifier:bundleID bundleURL:bundleURL];
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

- (UIImage *)iconForBundleIdentifier:(NSString *)bundleID {
    if ([bundleID length] == 0) {
        return nil;
    }

    CGFloat scale = [UIScreen mainScreen].scale ?: 2.0;
    NSArray<NSNumber *> *formats = @[@(MIIconVariantSmall), @(MIIconVariantSpotlight), @(MIIconVariantDefault)];
    if ([[UIImage class] respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)]) {
        for (NSNumber *format in formats) {
            UIImage *image = [UIImage _applicationIconImageForBundleIdentifier:bundleID format:(MIIconVariant)[format unsignedIntegerValue] scale:scale];
            if ([image isKindOfClass:[UIImage class]]) {
                return image;
            }
        }
    }

    return nil;
}

- (UIImage *)iconFromBundleURL:(NSURL *)bundleURL {
    if (bundleURL == nil) {
        return nil;
    }

    NSBundle *bundle = [NSBundle bundleWithURL:bundleURL];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfURL:[bundleURL URLByAppendingPathComponent:@"Info.plist"]];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    void (^addName)(id) = ^(id value) {
        if ([value isKindOfClass:[NSString class]] && [value length] > 0 && ![names containsObject:value]) {
            [names addObject:value];
        }
    };
    void (^addNamesFromIcons)(NSDictionary *) = ^(NSDictionary *icons) {
        NSDictionary *primaryIcon = [icons isKindOfClass:[NSDictionary class]] ? icons[@"CFBundlePrimaryIcon"] : nil;
        NSArray *iconFiles = [primaryIcon[@"CFBundleIconFiles"] isKindOfClass:[NSArray class]] ? primaryIcon[@"CFBundleIconFiles"] : nil;
        for (NSString *name in [iconFiles reverseObjectEnumerator]) {
            addName(name);
        }
        addName(primaryIcon[@"CFBundleIconName"]);
    };

    addNamesFromIcons(info[@"CFBundleIcons"]);
    addNamesFromIcons(info[@"CFBundleIcons~ipad"]);
    NSArray *legacyIconFiles = [info[@"CFBundleIconFiles"] isKindOfClass:[NSArray class]] ? info[@"CFBundleIconFiles"] : nil;
    for (NSString *name in [legacyIconFiles reverseObjectEnumerator]) {
        addName(name);
    }
    addName(info[@"CFBundleIconFile"]);

    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *name in names) {
        UIImage *image = [UIImage imageNamed:name inBundle:bundle compatibleWithTraitCollection:nil];
        if ([image isKindOfClass:[UIImage class]]) {
            return image;
        }

        NSMutableArray<NSString *> *candidates = [NSMutableArray array];
        NSString *extension = [name pathExtension];
        if ([extension length] > 0) {
            [candidates addObject:name];
        } else {
            [candidates addObject:[name stringByAppendingString:@"@3x.png"]];
            [candidates addObject:[name stringByAppendingString:@"@2x.png"]];
            [candidates addObject:[name stringByAppendingPathExtension:@"png"]];
            [candidates addObject:name];
        }
        for (NSString *candidate in candidates) {
            NSString *path = [[bundleURL path] stringByAppendingPathComponent:candidate];
            if (![fileManager fileExistsAtPath:path]) {
                continue;
            }
            image = [UIImage imageWithContentsOfFile:path];
            if ([image isKindOfClass:[UIImage class]]) {
                return image;
            }
        }
    }

    return nil;
}

- (UIImage *)iconForApplicationProxy:(LSApplicationProxy *)proxy bundleIdentifier:(NSString *)bundleID bundleURL:(NSURL *)bundleURL {
    NSArray<NSNumber *> *formats = @[@(MIIconVariantSmall), @(MIIconVariantSpotlight), @(MIIconVariantDefault)];
    if ([[UIImage class] respondsToSelector:@selector(_iconForResourceProxy:format:)]) {
        for (NSNumber *format in formats) {
            UIImage *image = [UIImage _iconForResourceProxy:proxy format:(MIIconVariant)[format unsignedIntegerValue]];
            if ([image isKindOfClass:[UIImage class]]) {
                return image;
            }
        }
    }

    UIImage *image = [self iconForBundleIdentifier:bundleID];
    if (image != nil) {
        return image;
    }

    SEL imageSelector = NSSelectorFromString(@"iconImageForVariant:");
    if ([proxy respondsToSelector:imageSelector]) {
        UIImage *(*imp)(id, SEL, NSInteger) = (UIImage *(*)(id, SEL, NSInteger))[proxy methodForSelector:imageSelector];
        for (NSNumber *variant in @[@2, @1, @0, @3]) {
            UIImage *image = imp(proxy, imageSelector, [variant integerValue]);
            if ([image isKindOfClass:[UIImage class]]) {
                return image;
            }
        }
    }
    SEL dataSelector = NSSelectorFromString(@"iconDataForVariant:");
    if ([proxy respondsToSelector:dataSelector]) {
        NSData *(*imp)(id, SEL, NSInteger) = (NSData *(*)(id, SEL, NSInteger))[proxy methodForSelector:dataSelector];
        for (NSNumber *variant in @[@2, @1, @0, @3]) {
            NSData *data = imp(proxy, dataSelector, [variant integerValue]);
            if ([data isKindOfClass:[NSData class]]) {
                UIImage *image = [UIImage imageWithData:data];
                if (image != nil) {
                    return image;
                }
            }
        }
    }

    image = [self iconFromBundleURL:bundleURL];
    if (image != nil) {
        return image;
    }

    return nil;
}

- (UIImage *)fallbackIcon {
    static UIImage *image;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize size = CGSizeMake(40.0, 40.0);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
        [[UIColor colorWithWhite:0.86 alpha:1.0] setFill];
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size.width, size.height) cornerRadius:9.0];
        [path fill];
        [[UIColor colorWithWhite:0.45 alpha:1.0] setStroke];
        UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(12.0, 12.0, 16.0, 16.0)];
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
            PSSpecifier *specifier = LHLinkSpecifier(name, self, [LHAppOverrideController class], @selector(previewStringForSpecifier:));
            [specifier setProperty:bundleID forKey:@"bundleIdentifier"];
            [specifier setProperty:name forKey:@"appName"];
            [specifier setProperty:bundleID forKey:@"subtitle"];
            [specifier setProperty:[self previewStringForBundleIdentifier:bundleID] forKey:@"preview"];
            [specifier setProperty:app[@"icon"] forKey:@"LHIconImage"];
            [specifier setProperty:NSClassFromString(@"LHAppOverrideCell") forKey:@"cellClass"];
            [specifier setProperty:@82.0 forKey:@"height"];
            [items addObject:specifier];
        }
        _specifiers = items;
    }
    return _specifiers;
}

- (NSString *)previewStringForBundleIdentifier:(NSString *)bundleID {
    LHPreferenceStore *store = [LHPreferenceStore sharedStore];
    BOOL override = [store hasOverrideForBundleIdentifier:bundleID];
    LHPreferencePolicy *policy = [store effectivePolicyForBundleIdentifier:bundleID];
    return LHPolicySummary(policy, override);
}

- (NSString *)previewStringForSpecifier:(PSSpecifier *)specifier {
    return [self previewStringForBundleIdentifier:[specifier propertyForKey:@"bundleIdentifier"]];
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
            LHGroupSpecifier(@"Seeds", @"Seeds shown here are internal Loupehole inputs, not values returned to protected apps."),
            LHValueSpecifier(@"Build seed", [store buildSeedString]),
            LHValueSpecifier(@"Root seed", [store rootSeedHexString]),
            LHGroupSpecifier(@"Seed roles", nil),
            LHValueSpecifier(@"Build seed role", @"Compile-time UUID used to derive generated package paths, loader/filter names, and seed-derivation labels. It is not the package runtime seed."),
            LHValueSpecifier(@"Root seed role", @"Random per-install package seed used as the practical runtime seed. Resetting it rotates generated values and seed-derived state paths for enabled apps."),
            LHValueSpecifier(@"Active scoped seed", @"Derived inside each target app from the root seed plus the selected scope. Custom seed scope uses its configured UUID instead of the root seed."),
            LHValueSpecifier(@"App-install marker", @"Per-app-install scope adds a random marker stored in that app's data. Deleting and reinstalling the app creates a new marker and rotates that app's seed."),
            LHGroupSpecifier(@"Seed Actions", nil),
            LHDestructiveButtonSpecifier(@"Reset Root Seed", self, @selector(confirmResetRootSeed)),
            LHGroupSpecifier(@"Paths", @"Paths are derived from generated package names at runtime."),
            LHValueSpecifier(@"Policy", [store policyPath]),
            LHValueSpecifier(@"Loader", [store loaderDylibPath]),
            LHValueSpecifier(@"Filter", [store filterPath]),
            LHValueSpecifier(@"Root seed directory", [[store rootSeedPath] stringByDeletingLastPathComponent]),
            LHValueSpecifier(@"Root seed file", [store rootSeedPath]),
            LHValueSpecifier(@"Support", [store supportDirectoryPath]),
            LHValueSpecifier(@"Preferences", [store preferencesDirectoryPath]),
            LHValueSpecifier(@"Caches", [store cacheDirectoryPath])
        ] mutableCopy];
    }
    return _specifiers;
}

- (void)confirmResetRootSeed {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset Root Seed"
                                                                   message:@"This writes a new random root seed. All enabled apps will derive new replacement values and new seed-derived state paths after they restart. Existing state is not migrated or deleted, and this cannot be undone unless you kept the old seed."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    UIAlertAction *resetAction = [UIAlertAction actionWithTitle:@"Reset Root Seed" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        NSError *error = nil;
        if (![[LHPreferenceStore sharedStore] resetRootSeedWithError:&error]) {
            LHPresentError(self, error);
            return;
        }
        _specifiers = nil;
        [self reloadSpecifiers];
    }];
    [alert addAction:resetAction];
    [self presentViewController:alert animated:YES completion:nil];
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

@end
