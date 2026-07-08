#include "LHSeedProvider.h"
#include "LHGeneratedConfig.h"

#import <Foundation/Foundation.h>

#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#ifndef THEOS_PACKAGE_INSTALL_PREFIX
#define THEOS_PACKAGE_INSTALL_PREFIX ""
#endif

#define LH_ROOTLESS_NS(path) @THEOS_PACKAGE_INSTALL_PREFIX path

LH_DERIVATION_LABEL(seed_provider, scoped_seed_value)
LH_DERIVATION_LABEL(seed_provider, app_install_marker_directory)
LH_DERIVATION_LABEL(seed_provider, app_install_marker_record)
LH_DERIVATION_LABEL(seed_provider, app_install_seed_value)

static NSData *LHSeedProviderDataFromSeed(const LHSeed *seed) {
    return [NSData dataWithBytes:seed->bytes length:sizeof(seed->bytes)];
}

static bool LHSeedProviderReadSeedAtPath(NSString *path, LHSeed *seed) {
    if (path == nil || seed == 0) {
        return false;
    }

    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data == nil || [data length] != sizeof(seed->bytes)) {
        return false;
    }

    memcpy(seed->bytes, [data bytes], sizeof(seed->bytes));
    return true;
}

static bool LHSeedProviderWriteSeedAtPath(NSString *path, const LHSeed *seed) {
    if (path == nil || seed == 0) {
        return false;
    }

    NSString *directory = [path stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil]) {
        return false;
    }
    chmod([directory fileSystemRepresentation], S_IRWXU);

    NSData *data = LHSeedProviderDataFromSeed(seed);
    if (![data writeToFile:path options:NSDataWritingAtomic error:nil]) {
        return false;
    }

    chmod([path fileSystemRepresentation], S_IRUSR | S_IWUSR);
    return true;
}

static NSString *LHSeedProviderPackageParentBasePath(void) {
    NSString *parentName = [NSString stringWithUTF8String:LHGeneratedConfigPackageStateParentDirectoryName];
    if (parentName == nil) {
        return nil;
    }

#if LH_STATE_TESTING
    const char *overrideRoot = getenv("LH_PACKAGE_STATE_TEST_ROOT");
    if (overrideRoot != 0 && overrideRoot[0] != '\0') {
        NSString *base = [[NSString stringWithUTF8String:overrideRoot] stringByAppendingPathComponent:@"var/mobile/Library/Application Support"];
        return [base stringByAppendingPathComponent:parentName];
    }
#endif

    NSString *base = LH_ROOTLESS_NS(@"/var/mobile/Library/Application Support");
    return [base stringByAppendingPathComponent:parentName];
}

static NSString *LHSeedProviderPackageRootSeedPath(void) {
    NSString *base = LHSeedProviderPackageParentBasePath();
    NSString *seedRoot = [NSString stringWithUTF8String:LHGeneratedConfigPackageSeedRootDirectoryName];
    NSString *seedFile = [NSString stringWithUTF8String:LHGeneratedConfigPackageRootSeedFileName];
    if (base == nil || seedRoot == nil || seedFile == nil) {
        return nil;
    }
    return [[base stringByAppendingPathComponent:seedRoot] stringByAppendingPathComponent:seedFile];
}

static NSString *LHSeedProviderLocalApplicationSupportPath(void) {
#if LH_STATE_TESTING
    const char *overrideHome = getenv("LH_APP_INSTALL_TEST_HOME");
    if (overrideHome == 0 || overrideHome[0] == '\0') {
        overrideHome = getenv("LH_STATE_TEST_HOME");
    }
    if (overrideHome != 0 && overrideHome[0] != '\0') {
        return [[NSString stringWithUTF8String:overrideHome] stringByAppendingPathComponent:@"Library/Application Support"];
    }
#endif

    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    return [paths firstObject];
}

static NSString *LHSeedProviderOpaquePath(NSString *base,
                                          const LHSeed *seed,
                                          const LHAppContext *context,
                                          const LHDerivationLabel *directoryLabel,
                                          const LHDerivationLabel *recordLabel) {
    if (base == nil || seed == 0 || context == 0 || directoryLabel == 0 || recordLabel == 0) {
        return nil;
    }

    char directoryName[33] = { 0 };
    if (!LHSeedDeriveOpaqueName(seed, directoryLabel, &context->scope, directoryName, sizeof(directoryName))) {
        return nil;
    }

    char recordName[33] = { 0 };
    if (!LHSeedDeriveOpaqueName(seed, recordLabel, &context->scope, recordName, sizeof(recordName))) {
        return nil;
    }

    NSString *directory = [base stringByAppendingPathComponent:[NSString stringWithUTF8String:directoryName]];
    return [directory stringByAppendingPathComponent:[NSString stringWithUTF8String:recordName]];
}

static NSString *LHSeedProviderAppInstallMarkerPath(const LHSeed *practicalSeed, const LHAppContext *context) {
    return LHSeedProviderOpaquePath(LHSeedProviderLocalApplicationSupportPath(),
                                    practicalSeed,
                                    context,
                                    &LHGeneratedDerivationLabel_seed_provider_app_install_marker_directory,
                                    &LHGeneratedDerivationLabel_seed_provider_app_install_marker_record);
}

static bool LHSeedProviderLoadOrCreateRootSeed(LHSeed *rootSeed) {
    NSString *path = LHSeedProviderPackageRootSeedPath();
    if (LHSeedProviderReadSeedAtPath(path, rootSeed)) {
        return true;
    }

    arc4random_buf(rootSeed->bytes, sizeof(rootSeed->bytes));
    return LHSeedProviderWriteSeedAtPath(path, rootSeed);
}

static bool LHSeedProviderLoadOrCreateRandomSeedAtPath(NSString *path, LHSeed *seed, bool requirePersistence) {
    if (LHSeedProviderReadSeedAtPath(path, seed)) {
        return true;
    }

    arc4random_buf(seed->bytes, sizeof(seed->bytes));
    if (LHSeedProviderWriteSeedAtPath(path, seed)) {
        return true;
    }
    return !requirePersistence;
}

static bool LHSeedProviderResolvePracticalSeed(const LHRuntimeConfig *config, LHSeed *practicalSeed) {
    if (config == 0 || practicalSeed == 0) {
        return false;
    }

    if (config->scopeMode == LHScopeModeManualLinkedGroup && config->customSeedEnabled) {
        *practicalSeed = config->customSeed;
        return true;
    }

    *practicalSeed = config->buildSeed;
    if (config->stateProviderKind != LHStateProviderKindPackage) {
        return true;
    }

    return LHSeedProviderLoadOrCreateRootSeed(practicalSeed);
}

static bool LHSeedProviderResolveAppInstallSeed(const LHSeed *practicalSeed, const LHAppContext *context, LHSeed *activeSeed) {
    LHSeed marker = { 0 };
    NSString *path = LHSeedProviderAppInstallMarkerPath(practicalSeed, context);
    if (!LHSeedProviderLoadOrCreateRandomSeedAtPath(path, &marker, false)) {
        return false;
    }

    return LHSeedDeriveBytesWithContext(practicalSeed,
                                        &LHGeneratedDerivationLabel_seed_provider_app_install_seed_value,
                                        &context->scope,
                                        marker.bytes,
                                        sizeof(marker.bytes),
                                        activeSeed->bytes,
                                        sizeof(activeSeed->bytes));
}

static bool LHSeedProviderResolveDeterministicScopedSeed(const LHSeed *practicalSeed,
                                                        const LHAppContext *context,
                                                        LHSeed *activeSeed) {
    return LHSeedDeriveBytes(practicalSeed,
                             &LHGeneratedDerivationLabel_seed_provider_scoped_seed_value,
                             &context->scope,
                             activeSeed->bytes,
                             sizeof(activeSeed->bytes));
}

bool LHSeedProviderResolveActiveSeed(LHRuntimeConfig *config, const LHAppContext *context) {
    @autoreleasepool {
        if (config == 0 || context == 0) {
            return false;
        }
        LHSeed practicalSeed = { 0 };
        LHSeed activeSeed = { 0 };
        if (!LHSeedProviderResolvePracticalSeed(config, &practicalSeed)) {
            return false;
        }

        if (context->scope.mode == LHScopeModePerAppInstall) {
            if (!LHSeedProviderResolveAppInstallSeed(&practicalSeed, context, &activeSeed)) {
                return false;
            }
        } else if (context->scope.mode == LHScopeModeManualLinkedGroup && config->customSeedEnabled) {
            activeSeed = practicalSeed;
        } else if (!LHSeedProviderResolveDeterministicScopedSeed(&practicalSeed, context, &activeSeed)) {
            return false;
        }

        config->buildSeed = activeSeed;
        return true;
    }
}
