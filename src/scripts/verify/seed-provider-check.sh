#!/bin/sh
set -eu

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/seed_provider_check.m" <<'SOURCE'
#include "LHAppContext.h"
#include "LHConfig.h"
#include "LHGeneratedConfig.h"
#include "LHSeedProvider.h"

#include <dirent.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <stdlib.h>

static int is_hex_name(const char *name) {
    if (strlen(name) != 32) {
        return 0;
    }
    for (size_t i = 0; i < 32; i++) {
        char c = name[i];
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) {
            return 0;
        }
    }
    return 1;
}

static int is_loader_basename(const char *name) {
    if (strlen(name) != 32 || name[0] != 'x') {
        return 0;
    }
    for (size_t i = 1; i < 32; i++) {
        char c = name[i];
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) {
            return 0;
        }
    }
    return strcmp(name, "runtime") != 0;
}

static int seed_file_size_is_16(const char *path) {
    struct stat st;
    return stat(path, &st) == 0 && st.st_size == 16;
}

static int has_opaque_file(const char *path) {
    DIR *dir = opendir(path);
    if (dir == 0) {
        return 0;
    }
    struct dirent *entry = 0;
    int found = 0;
    while ((entry = readdir(dir)) != 0) {
        if (!is_hex_name(entry->d_name)) {
            continue;
        }
        char child[4096] = {0};
        snprintf(child, sizeof(child), "%s/%s", path, entry->d_name);
        if (seed_file_size_is_16(child)) {
            found = 1;
            break;
        }
    }
    closedir(dir);
    return found;
}

static int has_app_install_marker(const char *name) {
    const char *base = getenv("LH_APP_INSTALL_TEST_BASE");
    if (base == 0 || base[0] == '\0') {
        return 0;
    }

    char path[4096] = {0};
    snprintf(path, sizeof(path), "%s/%s/Library/Application Support", base, name);

    DIR *dir = opendir(path);
    if (dir == 0) {
        return 0;
    }

    int found = 0;
    struct dirent *entry = 0;
    while ((entry = readdir(dir)) != 0) {
        if (!is_hex_name(entry->d_name)) {
            continue;
        }
        char child[4096] = {0};
        snprintf(child, sizeof(child), "%s/%s", path, entry->d_name);
        if (has_opaque_file(child)) {
            found = 1;
            break;
        }
    }
    closedir(dir);
    return found;
}

static int select_app_install_home(const char *name) {
    const char *base = getenv("LH_APP_INSTALL_TEST_BASE");
    if (base == 0 || base[0] == '\0') {
        return 0;
    }

    char path[4096] = {0};
    snprintf(path, sizeof(path), "%s/%s", base, name);
    return setenv("LH_APP_INSTALL_TEST_HOME", path, 1) == 0;
}

static int package_parent_path(char *path, size_t length) {
    const char *root = getenv("LH_PACKAGE_STATE_TEST_ROOT");
    if (root == 0 || root[0] == '\0') {
        return 0;
    }
    if (!is_hex_name(LHGeneratedConfigPackageStateParentDirectoryName)) {
        return 0;
    }
    snprintf(path,
             length,
             "%s/var/mobile/Library/Application Support/%s",
             root,
             LHGeneratedConfigPackageStateParentDirectoryName);
    return 1;
}

static int has_root_seed_file(void) {
    if (!is_hex_name(LHGeneratedConfigPackageSeedRootDirectoryName) ||
        !is_hex_name(LHGeneratedConfigPackageRootSeedFileName)) {
        return 0;
    }

    char parent[4096] = {0};
    if (!package_parent_path(parent, sizeof(parent))) {
        return 0;
    }

    char path[4096] = {0};
    snprintf(path,
             sizeof(path),
             "%s/%s/%s",
             parent,
             LHGeneratedConfigPackageSeedRootDirectoryName,
             LHGeneratedConfigPackageRootSeedFileName);
    return seed_file_size_is_16(path);
}

static int resolve_for_scope(LHScopeMode mode, const char *identifier, const LHSeed *buildSeed, LHSeed *activeSeed) {
    LHRuntimeConfig config = LHRuntimeConfigDefault();
    config.stateProviderKind = LHStateProviderKindPackage;
    config.buildSeed = *buildSeed;

    LHAppContext context;
    memset(&context, 0, sizeof(context));
    if (!LHScopeInit(&context.scope, mode, (const uint8_t *)identifier, strlen(identifier))) {
        return 0;
    }
    if (!LHSeedProviderResolveActiveSeed(&config, &context)) {
        return 0;
    }

    *activeSeed = config.buildSeed;
    return 1;
}

static int resolve_for_custom_seed(const char *seedString, const char *identifier, const LHSeed *buildSeed, LHSeed *activeSeed) {
    LHRuntimeConfig config = LHRuntimeConfigDefault();
    config.stateProviderKind = LHStateProviderKindPackage;
    config.buildSeed = *buildSeed;
    config.scopeMode = LHScopeModeManualLinkedGroup;
    config.customSeedEnabled = true;
    if (!LHSeedParseUUID(seedString, &config.customSeed)) {
        return 0;
    }

    LHAppContext context;
    memset(&context, 0, sizeof(context));
    if (!LHScopeInitManualLinkedGroup(&context.scope, identifier)) {
        return 0;
    }
    if (!LHSeedProviderResolveActiveSeed(&config, &context)) {
        return 0;
    }

    *activeSeed = config.buildSeed;
    return 1;
}

int main(void) {
    if (!is_loader_basename(LHGeneratedConfigPackageLoaderBaseName)) {
        return 29;
    }

    LHRuntimeConfig buildConfig = LHRuntimeConfigDefault();
    LHSeed buildSeed = buildConfig.buildSeed;
    LHSeed installFirst = {0};
    LHSeed installSecond = {0};
    LHSeed installOther = {0};
    LHSeed appFirst = {0};
    LHSeed appSecond = {0};
    LHSeed otherApp = {0};
    LHSeed customFirst = {0};
    LHSeed customSecond = {0};
    LHSeed customOtherSeed = {0};

    if (!select_app_install_home("install-one")) {
        return 20;
    }
    if (!resolve_for_scope(LHScopeModePerAppInstall, "com.example.install", &buildSeed, &installFirst)) {
        return 21;
    }
    if (!resolve_for_scope(LHScopeModePerAppInstall, "com.example.install", &buildSeed, &installSecond)) {
        return 22;
    }
    if (memcmp(installFirst.bytes, installSecond.bytes, sizeof(installFirst.bytes)) != 0) {
        return 23;
    }
    if (memcmp(installFirst.bytes, buildSeed.bytes, sizeof(installFirst.bytes)) == 0) {
        return 24;
    }
    if (!has_app_install_marker("install-one")) {
        return 25;
    }
    if (!select_app_install_home("install-two")) {
        return 26;
    }
    if (!resolve_for_scope(LHScopeModePerAppInstall, "com.example.install", &buildSeed, &installOther)) {
        return 27;
    }
    if (memcmp(installFirst.bytes, installOther.bytes, sizeof(installFirst.bytes)) == 0) {
        return 28;
    }

    if (!resolve_for_scope(LHScopeModePerApp, "com.example.one", &buildSeed, &appFirst)) {
        return 1;
    }
    if (!resolve_for_scope(LHScopeModePerApp, "com.example.one", &buildSeed, &appSecond)) {
        return 2;
    }
    if (memcmp(appFirst.bytes, appSecond.bytes, sizeof(appFirst.bytes)) != 0) {
        return 3;
    }
    if (memcmp(appFirst.bytes, buildSeed.bytes, sizeof(appFirst.bytes)) == 0) {
        return 4;
    }

    if (!resolve_for_scope(LHScopeModePerApp, "com.example.two", &buildSeed, &otherApp)) {
        return 5;
    }
    if (memcmp(appFirst.bytes, otherApp.bytes, sizeof(appFirst.bytes)) == 0) {
        return 6;
    }

    if (!resolve_for_custom_seed("11111111-1111-1111-1111-111111111111", "com.example.one", &buildSeed, &customFirst)) {
        return 30;
    }
    if (!resolve_for_custom_seed("11111111-1111-1111-1111-111111111111", "com.example.two", &buildSeed, &customSecond)) {
        return 31;
    }
    if (memcmp(customFirst.bytes, customSecond.bytes, sizeof(customFirst.bytes)) != 0) {
        return 32;
    }
    if (memcmp(customFirst.bytes, appFirst.bytes, sizeof(customFirst.bytes)) == 0) {
        return 33;
    }
    if (memcmp(customFirst.bytes, buildSeed.bytes, sizeof(customFirst.bytes)) == 0) {
        return 34;
    }
    if (!resolve_for_custom_seed("22222222-2222-2222-2222-222222222222", "com.example.one", &buildSeed, &customOtherSeed)) {
        return 35;
    }
    if (memcmp(customFirst.bytes, customOtherSeed.bytes, sizeof(customFirst.bytes)) == 0) {
        return 36;
    }

    if (!has_root_seed_file()) {
        return 11;
    }

    return 0;
}
SOURCE

HOME="$tmpdir" cc \
  -DLH_STATE_TESTING=1 \
  -Isrc/core/include \
  -Isrc/core/generated \
  src/core/generated/LHGeneratedConfig.c \
  src/core/generated/LHGeneratedDerivationLabels.c \
  src/runtime/config/LHConfig.c \
  src/runtime/scope/LHScope.c \
  src/runtime/seeds/LHSeed.c \
  src/runtime/seeds/LHSeedProvider.m \
  "$tmpdir/seed_provider_check.m" \
  -framework Foundation \
  -o "$tmpdir/seed_provider_check"

LH_PACKAGE_STATE_TEST_ROOT="$tmpdir/package" LH_APP_INSTALL_TEST_BASE="$tmpdir/apps" "$tmpdir/seed_provider_check"
printf '%s\n' "seed provider check passed"
