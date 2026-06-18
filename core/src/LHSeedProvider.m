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

LH_DERIVATION_LABEL(seed_provider, scoped_seed_directory)
LH_DERIVATION_LABEL(seed_provider, scoped_seed_record)
LH_DERIVATION_LABEL(seed_provider, scoped_seed_value)

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

static NSString *LHSeedProviderScopedSeedDirectory(const LHRuntimeConfig *config, const LHAppContext *context) {
    NSString *base = LHSeedProviderPackageParentBasePath();
    if (base == nil) {
        return nil;
    }

    char name[33] = { 0 };
    if (!LHSeedDeriveOpaqueName(&config->instanceSeed,
                                &LHGeneratedDerivationLabel_seed_provider_scoped_seed_directory,
                                &context->scope,
                                name,
                                sizeof(name))) {
        return nil;
    }
    return [base stringByAppendingPathComponent:[NSString stringWithUTF8String:name]];
}

static NSString *LHSeedProviderScopedSeedPath(const LHRuntimeConfig *config, const LHAppContext *context) {
    NSString *directory = LHSeedProviderScopedSeedDirectory(config, context);
    if (directory == nil) {
        return nil;
    }

    char name[33] = { 0 };
    if (!LHSeedDeriveOpaqueName(&config->instanceSeed,
                                &LHGeneratedDerivationLabel_seed_provider_scoped_seed_record,
                                &context->scope,
                                name,
                                sizeof(name))) {
        return nil;
    }
    return [directory stringByAppendingPathComponent:[NSString stringWithUTF8String:name]];
}

static bool LHSeedProviderLoadOrCreateRootSeed(LHSeed *rootSeed) {
    NSString *path = LHSeedProviderPackageRootSeedPath();
    if (LHSeedProviderReadSeedAtPath(path, rootSeed)) {
        return true;
    }

    arc4random_buf(rootSeed->bytes, sizeof(rootSeed->bytes));
    return LHSeedProviderWriteSeedAtPath(path, rootSeed);
}

static bool LHSeedProviderLoadOrCreateScopedSeed(const LHRuntimeConfig *buildConfig,
                                                 const LHAppContext *context,
                                                 const LHSeed *rootSeed,
                                                 LHSeed *scopedSeed) {
    NSString *path = LHSeedProviderScopedSeedPath(buildConfig, context);
    if (LHSeedProviderReadSeedAtPath(path, scopedSeed)) {
        return true;
    }

    if (!LHSeedDeriveBytes(rootSeed,
                           &LHGeneratedDerivationLabel_seed_provider_scoped_seed_value,
                           &context->scope,
                           scopedSeed->bytes,
                           sizeof(scopedSeed->bytes))) {
        return false;
    }
    return LHSeedProviderWriteSeedAtPath(path, scopedSeed);
}

bool LHSeedProviderResolveActiveSeed(LHRuntimeConfig *config, const LHAppContext *context) {
    @autoreleasepool {
        if (config == 0 || context == 0) {
            return false;
        }
        if (config->stateProviderKind != LHStateProviderKindPackage) {
            return true;
        }

        LHRuntimeConfig buildConfig = *config;
        LHSeed rootSeed = { 0 };
        LHSeed scopedSeed = { 0 };

        if (!LHSeedProviderLoadOrCreateRootSeed(&rootSeed)) {
            return false;
        }
        if (!LHSeedProviderLoadOrCreateScopedSeed(&buildConfig, context, &rootSeed, &scopedSeed)) {
            return false;
        }

        config->instanceSeed = scopedSeed;
        return true;
    }
}
