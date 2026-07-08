#include "LHStateProvider.h"
#include "LHGeneratedConfig.h"

#import <Foundation/Foundation.h>

#include <stdlib.h>
#include <string.h>

#ifndef THEOS_PACKAGE_INSTALL_PREFIX
#define THEOS_PACKAGE_INSTALL_PREFIX ""
#endif

#define LH_ROOTLESS_NS(path) @THEOS_PACKAGE_INSTALL_PREFIX path

LH_DERIVATION_LABEL(package_state, root)

/** Wraps raw bytes in immutable NSData for plist storage. */
static NSData *LHDataFromBytes(const uint8_t *bytes, size_t length) {
    return [NSData dataWithBytes:bytes length:length];
}

/** Derives the opaque filename for a state key. */
static NSString *LHStateBlobName(const LHRuntimeConfig *config, const LHAppContext *context, const LHStateKey *key) {
    char name[33] = { 0 };
    if (!LHSeedDeriveOpaqueName(&config->buildSeed,
                                &key->label,
                                &context->scope,
                                name,
                                sizeof(name))) {
        return nil;
    }
    return [NSString stringWithUTF8String:name];
}

/** Returns the local standalone-mode state blob path. */
static NSString *LHStateBlobPath(const LHRuntimeConfig *config, const LHAppContext *context, const LHStateKey *key) {
#if LH_STATE_TESTING
    const char *overrideHome = getenv("LH_STATE_TEST_HOME");
    if (overrideHome != 0 && overrideHome[0] != '\0') {
        NSString *name = LHStateBlobName(config, context, key);
        if (name == nil) {
            return nil;
        }
        NSString *base = [[NSString stringWithUTF8String:overrideHome] stringByAppendingPathComponent:@"Library/Application Support"];
        return [base stringByAppendingPathComponent:name];
    }
#endif

    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *base = [paths firstObject];
    NSString *name = LHStateBlobName(config, context, key);
    if (base == nil || name == nil) {
        return nil;
    }
    return [base stringByAppendingPathComponent:name];
}

/** Derives the package-mode per-scope state root directory name. */
static NSString *LHPackageStateRootName(const LHRuntimeConfig *config, const LHAppContext *context) {
    char name[33] = { 0 };
    if (!LHSeedDeriveOpaqueName(&config->buildSeed,
                                &LHGeneratedDerivationLabel_package_state_root,
                                &context->scope,
                                name,
                                sizeof(name))) {
        return nil;
    }
    return [NSString stringWithUTF8String:name];
}

/** Returns the package-mode per-scope state base path. */
static NSString *LHPackageStateBasePath(const LHRuntimeConfig *config, const LHAppContext *context) {
    NSString *rootName = LHPackageStateRootName(config, context);
    if (rootName == nil) {
        return nil;
    }
    NSString *parentName = [NSString stringWithUTF8String:LHGeneratedConfigPackageStateParentDirectoryName];
    if (parentName == nil) {
        return nil;
    }

#if LH_STATE_TESTING
    const char *overrideRoot = getenv("LH_PACKAGE_STATE_TEST_ROOT");
    if (overrideRoot != 0 && overrideRoot[0] != '\0') {
        NSString *base = [[NSString stringWithUTF8String:overrideRoot] stringByAppendingPathComponent:@"var/mobile/Library/Application Support"];
        return [[base stringByAppendingPathComponent:parentName] stringByAppendingPathComponent:rootName];
    }
#endif

    NSString *base = LH_ROOTLESS_NS(@"/var/mobile/Library/Application Support");
    return [[base stringByAppendingPathComponent:parentName] stringByAppendingPathComponent:rootName];
}

/** Returns the package-mode state blob path for a key. */
static NSString *LHPackageStateBlobPath(const LHRuntimeConfig *config, const LHAppContext *context, const LHStateKey *key) {
    NSString *base = LHPackageStateBasePath(config, context);
    NSString *name = LHStateBlobName(config, context, key);
    if (base == nil || name == nil) {
        return nil;
    }
    return [base stringByAppendingPathComponent:name];
}

/** Reads and validates a serialized state blob. */
static bool LHStateReadBytes(NSString *path, const LHStateKey *key, uint8_t *output, size_t outputLength) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data == nil) {
        return false;
    }

    NSError *error = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&error];
    if (![plist isKindOfClass:[NSDictionary class]]) {
        return false;
    }

    NSDictionary *dictionary = (NSDictionary *)plist;
    NSNumber *schema = dictionary[@"v"];
    NSData *payload = dictionary[@"d"];
    if (![schema isKindOfClass:[NSNumber class]] ||
        ![payload isKindOfClass:[NSData class]] ||
        [schema unsignedIntValue] != key->schemaVersion ||
        [payload length] != outputLength) {
        return false;
    }

    memcpy(output, [payload bytes], outputLength);
    return true;
}

/** Writes a serialized state blob with schema and payload fields. */
static bool LHStateWriteBytes(NSString *path, const LHStateKey *key, const uint8_t *bytes, size_t length) {
    NSString *directory = [path stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil]) {
        return false;
    }

    NSDictionary *dictionary = @{
        @"v": @(key->schemaVersion),
        @"d": LHDataFromBytes(bytes, length)
    };

    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:dictionary format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    if (data == nil) {
        return false;
    }

    return [data writeToFile:path options:NSDataWritingAtomic error:nil];
}

/** Invokes a state generator after clearing the output buffer. */
static bool LHStateGenerate(const LHRuntimeConfig *config,
                            const LHAppContext *context,
                            LHStateGenerateBytes generate,
                            void *generatorContext,
                            uint8_t *output,
                            size_t outputLength) {
    memset(output, 0, outputLength);
    return generate != 0 && generate(config, context, generatorContext, output, outputLength);
}

/** Loads or creates a standalone-mode state blob. */
static bool LHStateProviderLoadLocal(const LHRuntimeConfig *config,
                                     const LHAppContext *context,
                                     const LHStateKey *key,
                                     uint8_t *output,
                                     size_t outputLength,
                                     LHStateGenerateBytes generate,
                                     void *generatorContext,
                                     LHStateLoadResult *result) {
    NSString *path = LHStateBlobPath(config, context, key);
    if (path == nil) {
        return false;
    }

    if (LHStateReadBytes(path, key, output, outputLength)) {
        if (result != 0) {
            result->local = true;
            result->created = false;
        }
        return true;
    }

    if (!LHStateGenerate(config, context, generate, generatorContext, output, outputLength)) {
        return false;
    }
    if (!LHStateWriteBytes(path, key, output, outputLength)) {
        return false;
    }

    if (result != 0) {
        result->local = true;
        result->created = true;
    }
    return true;
}

/** Loads or creates a package-mode state blob. */
static bool LHStateProviderLoadPackage(const LHRuntimeConfig *config,
                                       const LHAppContext *context,
                                       const LHStateKey *key,
                                       uint8_t *output,
                                       size_t outputLength,
                                       LHStateGenerateBytes generate,
                                       void *generatorContext,
                                       LHStateLoadResult *result) {
    NSString *path = LHPackageStateBlobPath(config, context, key);
    if (path == nil) {
        return false;
    }

    if (LHStateReadBytes(path, key, output, outputLength)) {
        if (result != 0) {
            result->local = true;
            result->created = false;
        }
        return true;
    }

    if (!LHStateGenerate(config, context, generate, generatorContext, output, outputLength)) {
        return false;
    }
    if (!LHStateWriteBytes(path, key, output, outputLength)) {
        return false;
    }

    if (result != 0) {
        result->local = true;
        result->created = true;
    }
    return true;
}

/** Loads or creates state through the configured local, package, or embedded backend. */
bool LHStateProviderLoadOrCreate(const LHRuntimeConfig *config,
                                 const LHAppContext *context,
                                 const LHStateKey *key,
                                 uint8_t *output,
                                 size_t outputLength,
                                 LHStateGenerateBytes generate,
                                 void *generatorContext,
                                 LHStateLoadResult *result) {
    @autoreleasepool {
        if (config == 0 || context == 0 || key == 0 || output == 0 || outputLength == 0 || generate == 0) {
            return false;
        }

        if (result != 0) {
            memset(result, 0, sizeof(*result));
        }

        if (config->stateProviderKind == LHStateProviderKindLocal &&
            LHStateProviderLoadLocal(config, context, key, output, outputLength, generate, generatorContext, result)) {
            return true;
        }

        if (config->stateProviderKind == LHStateProviderKindPackage &&
            LHStateProviderLoadPackage(config, context, key, output, outputLength, generate, generatorContext, result)) {
            return true;
        }

        if (!LHStateGenerate(config, context, generate, generatorContext, output, outputLength)) {
            return false;
        }
        if (result != 0) {
            result->local = false;
            result->created = true;
        }
        return true;
    }
}
