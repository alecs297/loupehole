#include "LHConfigProvider.h"
#include "LHGeneratedConfig.h"

#import <Foundation/Foundation.h>

#include <stdlib.h>
#include <string.h>

#ifndef THEOS_PACKAGE_INSTALL_PREFIX
#define THEOS_PACKAGE_INSTALL_PREFIX ""
#endif

#define LH_ROOTLESS_NS(path) @THEOS_PACKAGE_INSTALL_PREFIX path

typedef struct LHParsedPolicy {
    bool enabled;
    LHScopeMode scopeMode;
    bool moduleFilterEnabled;
    uint32_t moduleIDs[LHRuntimeConfigMaxEnabledModules];
    size_t moduleIDCount;
    bool customSeedEnabled;
    LHSeed customSeed;
} LHParsedPolicy;

/** Returns the package-mode preferences directory for runtime policy files. */
static NSString *LHConfigProviderPackagePreferencesBasePath(void) {
    NSString *parentName = [NSString stringWithUTF8String:LHGeneratedConfigPackageStateParentDirectoryName];
    if (parentName == nil) {
        return nil;
    }

#if LH_STATE_TESTING
    const char *overrideRoot = getenv("LH_PACKAGE_CONFIG_TEST_ROOT");
    if (overrideRoot == 0 || overrideRoot[0] == '\0') {
        overrideRoot = getenv("LH_PACKAGE_STATE_TEST_ROOT");
    }
    if (overrideRoot != 0 && overrideRoot[0] != '\0') {
        NSString *base = [[NSString stringWithUTF8String:overrideRoot] stringByAppendingPathComponent:@"var/mobile/Library/Preferences"];
        return [base stringByAppendingPathComponent:parentName];
    }
#endif

    NSString *base = LH_ROOTLESS_NS(@"/var/mobile/Library/Preferences");
    return [base stringByAppendingPathComponent:parentName];
}

/** Returns the generated package-mode policy file path. */
static NSString *LHConfigProviderPackagePolicyPath(void) {
    NSString *base = LHConfigProviderPackagePreferencesBasePath();
    NSString *fileName = [NSString stringWithUTF8String:LHGeneratedConfigPackagePolicyFileName];
    if (base == nil || fileName == nil) {
        return nil;
    }
    return [base stringByAppendingPathComponent:fileName];
}

/** Parses an unsigned 32-bit integer from a full string. */
static bool LHConfigProviderParseUnsigned(NSString *text, uint32_t *value) {
    if (![text isKindOfClass:[NSString class]] || value == 0 || [text length] == 0) {
        return false;
    }

    NSScanner *scanner = [NSScanner scannerWithString:text];
    unsigned long long parsed = 0;
    if (![scanner scanUnsignedLongLong:&parsed] || ![scanner isAtEnd] || parsed > UINT32_MAX) {
        return false;
    }
    *value = (uint32_t)parsed;
    return true;
}

/** Parses a serialized boolean field. */
static bool LHConfigProviderParseBool(NSString *text, bool *value) {
    uint32_t parsed = 0;
    if (!LHConfigProviderParseUnsigned(text, &parsed) || parsed > 1 || value == 0) {
        return false;
    }
    *value = parsed == 1;
    return true;
}

/** Parses a serialized scope mode field. */
static bool LHConfigProviderParseScopeMode(NSString *text, LHScopeMode *mode) {
    uint32_t parsed = 0;
    if (!LHConfigProviderParseUnsigned(text, &parsed) || parsed > LHScopeModeManualLinkedGroup || mode == 0) {
        return false;
    }
    *mode = (LHScopeMode)parsed;
    return true;
}

/** Parses a comma-delimited module filter list. */
static bool LHConfigProviderParseModules(NSString *text, LHParsedPolicy *policy) {
    if (text == nil || policy == 0) {
        return false;
    }
    policy->moduleIDCount = 0;
    memset(policy->moduleIDs, 0, sizeof(policy->moduleIDs));

    if ([text length] == 0) {
        return true;
    }

    NSArray<NSString *> *items = [text componentsSeparatedByString:@","];
    for (NSString *item in items) {
        if ([item length] == 0 || policy->moduleIDCount >= LHRuntimeConfigMaxEnabledModules) {
            return false;
        }

        uint32_t moduleID = 0;
        if (!LHConfigProviderParseUnsigned(item, &moduleID) || moduleID == 0) {
            return false;
        }

        bool duplicate = false;
        for (size_t i = 0; i < policy->moduleIDCount; i++) {
            if (policy->moduleIDs[i] == moduleID) {
                duplicate = true;
                break;
            }
        }
        if (!duplicate) {
            policy->moduleIDs[policy->moduleIDCount++] = moduleID;
        }
    }
    return true;
}

/** Parses one default or bundle-specific serialized policy record. */
static bool LHConfigProviderParsePolicyFields(NSArray<NSString *> *fields, NSUInteger offset, LHParsedPolicy *policy) {
    if (fields == nil || policy == 0 || [fields count] < offset + 5) {
        return false;
    }

    bool enabled = false;
    LHScopeMode scopeMode = LHScopeModePerAppInstall;
    bool moduleFilterEnabled = false;
    if (!LHConfigProviderParseBool(fields[offset], &enabled) ||
        !LHConfigProviderParseScopeMode(fields[offset + 1], &scopeMode) ||
        !LHConfigProviderParseBool(fields[offset + 2], &moduleFilterEnabled)) {
        return false;
    }

    LHParsedPolicy parsed = {
        .enabled = enabled,
        .scopeMode = scopeMode,
        .moduleFilterEnabled = moduleFilterEnabled
    };
    if (!LHConfigProviderParseModules(fields[offset + 3], &parsed)) {
        return false;
    }
    NSString *customSeedText = fields[offset + 4];
    if ([customSeedText length] > 0) {
        if (!LHSeedParseUUID([customSeedText UTF8String], &parsed.customSeed)) {
            return false;
        }
        parsed.customSeedEnabled = true;
    }
    if (scopeMode == LHScopeModeManualLinkedGroup && !parsed.customSeedEnabled) {
        return false;
    }

    *policy = parsed;
    return true;
}

/** Copies a parsed policy record into the active runtime configuration. */
static void LHConfigProviderApplyParsedPolicy(LHRuntimeConfig *config, const LHParsedPolicy *policy) {
    if (config == 0 || policy == 0) {
        return;
    }

    config->policyEnabled = policy->enabled;
    config->scopeMode = policy->scopeMode;
    config->moduleFilterEnabled = policy->moduleFilterEnabled;
    config->enabledModuleIDCount = policy->moduleIDCount;
    config->customSeedEnabled = policy->customSeedEnabled;
    config->customSeed = policy->customSeed;
    memset(config->enabledModuleIDs, 0, sizeof(config->enabledModuleIDs));
    if (policy->moduleIDCount > 0) {
        memcpy(config->enabledModuleIDs, policy->moduleIDs, policy->moduleIDCount * sizeof(policy->moduleIDs[0]));
    }
}

/** Applies the package-mode policy file to the active runtime configuration. */
bool LHConfigProviderApplyRuntimePolicy(LHRuntimeConfig *config, const LHAppContext *context) {
    @autoreleasepool {
        if (config == 0 || context == 0) {
            return false;
        }
        if (config->stateProviderKind != LHStateProviderKindPackage) {
            return true;
        }

        NSString *path = LHConfigProviderPackagePolicyPath();
        if (path == nil) {
            return true;
        }

        NSError *error = nil;
        NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
        if (text == nil) {
            return true;
        }

        NSString *bundleIdentifier = nil;
        if (context->bundleIdentifierLength > 0) {
            bundleIdentifier = [NSString stringWithUTF8String:context->bundleIdentifier];
        }

        LHParsedPolicy effective = {
            .enabled = config->policyEnabled,
            .scopeMode = config->scopeMode,
            .moduleFilterEnabled = config->moduleFilterEnabled,
            .moduleIDCount = config->enabledModuleIDCount,
            .customSeedEnabled = config->customSeedEnabled,
            .customSeed = config->customSeed
        };
        if (effective.moduleIDCount > 0) {
            memcpy(effective.moduleIDs, config->enabledModuleIDs, effective.moduleIDCount * sizeof(effective.moduleIDs[0]));
        }

        NSArray<NSString *> *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        for (NSString *line in lines) {
            NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([trimmed length] == 0) {
                continue;
            }

            NSArray<NSString *> *fields = [trimmed componentsSeparatedByString:@"|"];
            NSString *kind = [fields firstObject];
            if ([kind isEqualToString:@"D"]) {
                LHParsedPolicy parsed;
                if (LHConfigProviderParsePolicyFields(fields, 1, &parsed)) {
                    effective = parsed;
                }
            } else if ([kind isEqualToString:@"B"] && bundleIdentifier != nil && [fields count] >= 7 && [fields[1] isEqualToString:bundleIdentifier]) {
                LHParsedPolicy parsed;
                if (LHConfigProviderParsePolicyFields(fields, 2, &parsed)) {
                    effective = parsed;
                }
            }
        }

        LHConfigProviderApplyParsedPolicy(config, &effective);
        return true;
    }
}
