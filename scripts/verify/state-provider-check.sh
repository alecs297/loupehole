#!/bin/sh
set -eu

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/state_check.m" <<'SOURCE'
#include "LHAppContext.h"
#include "LHConfig.h"
#include "LHGeneratedConfig.h"
#include "LHStateProvider.h"

#include <dirent.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

typedef struct LHTestStateBlob {
    uint8_t value[16];
    uint32_t marker;
} LHTestStateBlob;

static const LHDerivationLabel LHTestStateValueLabel = {
    .bytes = { 0x71, 0x20, 0x5c, 0x6b, 0x99, 0x3f, 0x48, 0x51, 0x86, 0x1f, 0xc4, 0xfa, 0x2d, 0x45, 0xee, 0x10 }
};

static const LHStateKey LHTestStateKey = {
    .label = { .bytes = { 0x2a, 0x53, 0xbc, 0x81, 0xe0, 0x44, 0x40, 0xab, 0x93, 0x0d, 0x7f, 0x1b, 0xca, 0x52, 0x64, 0x9a } },
    .schemaVersion = 7
};

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

static int has_opaque_file(const char *path) {
    DIR *dir = opendir(path);
    if (dir == 0) {
        return 0;
    }
    struct dirent *entry = 0;
    int found = 0;
    while ((entry = readdir(dir)) != 0) {
        if (is_hex_name(entry->d_name)) {
            found = 1;
            break;
        }
    }
    closedir(dir);
    return found;
}

static int has_opaque_state_file(void) {
    const char *home = getenv("LH_STATE_TEST_HOME");
    if (home == 0) {
        return 0;
    }
    char path[4096] = {0};
    snprintf(path, sizeof(path), "%s/Library/Application Support", home);
    return has_opaque_file(path);
}

static bool generate_state(const LHRuntimeConfig *config,
                           const LHAppContext *context,
                           void *generatorContext,
                           uint8_t *output,
                           size_t outputLength) {
    (void)generatorContext;
    if (outputLength != sizeof(LHTestStateBlob)) {
        return false;
    }

    LHTestStateBlob blob;
    memset(&blob, 0, sizeof(blob));
    if (!LHSeedDeriveBytes(&config->instanceSeed, &LHTestStateValueLabel, &context->scope, blob.value, sizeof(blob.value))) {
        return false;
    }
    blob.marker = 0x5a17c0de;
    memcpy(output, &blob, sizeof(blob));
    return true;
}

int main(void) {
    LHRuntimeConfig config = LHRuntimeConfigDefault();
    LHRuntimeConfig otherConfig = LHRuntimeConfigDefault();
    LHAppContext context;
    LHTestStateBlob first;
    LHTestStateBlob second;
    LHTestStateBlob embedded;
    LHStateLoadResult firstResult;
    LHStateLoadResult secondResult;
    LHStateLoadResult embeddedResult;

    if (!LHGeneratedConfigHasInstanceSeed &&
        memcmp(config.instanceSeed.bytes, otherConfig.instanceSeed.bytes, sizeof(config.instanceSeed.bytes)) == 0) {
        return 10;
    }
    if (LHGeneratedConfigHasInstanceSeed &&
        memcmp(config.instanceSeed.bytes, otherConfig.instanceSeed.bytes, sizeof(config.instanceSeed.bytes)) != 0) {
        return 12;
    }

    if (!LHAppContextInitCurrentWithScopeMode(&context, config.scopeMode)) {
        return 1;
    }
    if (!LHStateProviderLoadOrCreate(&config, &context, &LHTestStateKey, (uint8_t *)&first, sizeof(first), generate_state, 0, &firstResult)) {
        return 2;
    }
    if (!firstResult.local || !firstResult.created || first.marker != 0x5a17c0de) {
        return 3;
    }
    if (!LHStateProviderLoadOrCreate(&config, &context, &LHTestStateKey, (uint8_t *)&second, sizeof(second), generate_state, 0, &secondResult)) {
        return 4;
    }
    if (memcmp(&first, &second, sizeof(first)) != 0) {
        return 5;
    }
    if (!secondResult.local || secondResult.created) {
        return 6;
    }

    config.stateProviderKind = LHStateProviderKindEmbedded;
    if (!LHStateProviderLoadOrCreate(&config, &context, &LHTestStateKey, (uint8_t *)&embedded, sizeof(embedded), generate_state, 0, &embeddedResult)) {
        return 7;
    }
    if (embeddedResult.local || !embeddedResult.created) {
        return 8;
    }
    if (!has_opaque_state_file()) {
        return 9;
    }
    if (memcmp(&first, &embedded, sizeof(first)) != 0) {
        return 11;
    }

    return 0;
}
SOURCE

HOME="$tmpdir" cc \
  -DLH_STATE_TESTING=1 \
  -Icore/include \
  -Icore/generated \
  core/generated/LHGeneratedConfig.c \
  core/src/LHAppContext.m \
  core/src/LHConfig.c \
  core/src/LHScope.c \
  core/src/LHSeed.c \
  core/src/LHStateProvider.m \
  "$tmpdir/state_check.m" \
  -framework Foundation \
  -o "$tmpdir/state_check"

LH_STATE_TEST_HOME="$tmpdir" "$tmpdir/state_check"
printf '%s\n' "state provider check passed"
