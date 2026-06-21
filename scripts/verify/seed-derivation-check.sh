#!/bin/sh
set -eu

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/seed_check.c" <<'SOURCE'
#include "LHScope.h"
#include "LHSeed.h"

#include <stdio.h>
#include <string.h>

typedef bool (*ScopeInit)(LHScope *scope, const char *identifier);

static const LHDerivationLabel LHTestBytesLabel = {
    .bytes = { 0x41, 0x8c, 0x7d, 0xb5, 0x0f, 0x63, 0x44, 0xaa, 0x81, 0x25, 0x39, 0x4d, 0x0e, 0x91, 0x56, 0xc8 }
};

static const LHDerivationLabel LHTestNameLabel = {
    .bytes = { 0x8d, 0x12, 0xf4, 0xa1, 0x77, 0x30, 0x4c, 0x26, 0x9e, 0x42, 0x1d, 0xe8, 0x5a, 0x04, 0xbb, 0x93 }
};

static int derive(ScopeInit init, const char *scopeText, unsigned char output[32]) {
    LHSeed seed;
    LHScope scope;
    if (!LHSeedParseUUID("123e4567-e89b-12d3-a456-426614174000", &seed)) {
        return 1;
    }
    if (!init(&scope, scopeText)) {
        return 2;
    }
    if (!LHSeedDeriveBytes(&seed, &LHTestBytesLabel, &scope, output, 32)) {
        return 3;
    }
    return 0;
}

static int derive_name(ScopeInit init, const char *scopeText, char output[33]) {
    LHSeed seed;
    LHScope scope;
    if (!LHSeedParseUUID("123e4567-e89b-12d3-a456-426614174000", &seed)) {
        return 1;
    }
    if (!init(&scope, scopeText)) {
        return 2;
    }
    if (!LHSeedDeriveOpaqueName(&seed, &LHTestNameLabel, &scope, output, 33)) {
        return 3;
    }
    return 0;
}

static int is_random_fallback_identifier(const LHScope *scope) {
    if (scope->identifierLength != 32) {
        return 0;
    }
    for (size_t index = 0; index < scope->identifierLength; index++) {
        unsigned char byte = scope->identifier[index];
        if (!((byte >= 'a' && byte <= 'z') ||
              (byte >= 'A' && byte <= 'Z') ||
              (byte >= '0' && byte <= '9'))) {
            return 0;
        }
    }
    return 1;
}

int main(void) {
    unsigned char first[32] = {0};
    unsigned char second[32] = {0};
    unsigned char other[32] = {0};
    unsigned char install[32] = {0};
    unsigned char vendor[32] = {0};
    unsigned char manual[32] = {0};
    unsigned char manualOther[32] = {0};
    unsigned char contextFirst[32] = {0};
    unsigned char contextSecond[32] = {0};
    unsigned char contextOther[32] = {0};
    char firstName[33] = {0};
    char secondName[33] = {0};
    LHSeed parsed;
    LHScope contextScope;
    LHScope fallbackNilFirst;
    LHScope fallbackNilSecond;
    LHScope fallbackEmpty;
    LHScope fallbackLong;
    char longIdentifier[160];
    static const uint8_t contextA[] = { 1, 2, 3, 4 };
    static const uint8_t contextB[] = { 4, 3, 2, 1 };

    if (!LHSeedParseUUID("00000000-0000-0000-0000-000000000000", &parsed)) {
        return 1;
    }
    if (!LHSeedParseUUID("123e4567-e89b-42d3-a456-426614174000", &parsed)) {
        return 1;
    }
    if (LHSeedParseUUID("not-a-uuid", &parsed)) {
        return 1;
    }

    if (derive(LHScopeInitPerApp, "example.one", first) != 0) {
        return 2;
    }
    if (derive(LHScopeInitPerApp, "example.one", second) != 0) {
        return 2;
    }
    if (derive(LHScopeInitPerApp, "example.two", other) != 0) {
        return 3;
    }
    if (derive(LHScopeInitPerAppInstall, "example.one", install) != 0) {
        return 15;
    }
    if (derive(LHScopeInitPerVendorGroup, "example.one", vendor) != 0) {
        return 4;
    }
    if (derive(LHScopeInitManualLinkedGroup, "example.one", manual) != 0) {
        return 6;
    }
    if (derive(LHScopeInitManualLinkedGroup, "example.two", manualOther) != 0) {
        return 5;
    }
    if (derive_name(LHScopeInitPerApp, "example.one", firstName) != 0) {
        return 7;
    }
    if (derive_name(LHScopeInitPerApp, "example.one", secondName) != 0) {
        return 8;
    }

    if (memcmp(first, second, sizeof(first)) != 0) {
        return 9;
    }
    if (memcmp(first, other, sizeof(first)) == 0) {
        return 10;
    }
    if (memcmp(first, install, sizeof(first)) == 0) {
        return 15;
    }
    if (memcmp(first, vendor, sizeof(first)) == 0) {
        return 11;
    }
    if (memcmp(first, manual, sizeof(first)) == 0) {
        return 13;
    }
    if (memcmp(manual, manualOther, sizeof(manual)) != 0) {
        return 12;
    }
    if (strcmp(firstName, secondName) != 0 || strlen(firstName) != 32) {
        return 14;
    }
    if (!LHScopeInitPerApp(&contextScope, "example.one")) {
        return 16;
    }
    if (!LHSeedDeriveBytesWithContext(&parsed, &LHTestBytesLabel, &contextScope, contextA, sizeof(contextA), contextFirst, sizeof(contextFirst))) {
        return 17;
    }
    if (!LHSeedDeriveBytesWithContext(&parsed, &LHTestBytesLabel, &contextScope, contextA, sizeof(contextA), contextSecond, sizeof(contextSecond))) {
        return 18;
    }
    if (!LHSeedDeriveBytesWithContext(&parsed, &LHTestBytesLabel, &contextScope, contextB, sizeof(contextB), contextOther, sizeof(contextOther))) {
        return 19;
    }
    if (memcmp(contextFirst, contextSecond, sizeof(contextFirst)) != 0) {
        return 20;
    }
    if (memcmp(contextFirst, contextOther, sizeof(contextFirst)) == 0 || memcmp(contextFirst, first, sizeof(contextFirst)) == 0) {
        return 21;
    }
    memset(longIdentifier, 'x', sizeof(longIdentifier) - 1);
    longIdentifier[sizeof(longIdentifier) - 1] = '\0';
    if (!LHScopeInitPerApp(&fallbackNilFirst, 0) ||
        !LHScopeInitPerApp(&fallbackNilSecond, 0) ||
        !LHScopeInitPerApp(&fallbackEmpty, "") ||
        !LHScopeInitPerApp(&fallbackLong, longIdentifier)) {
        return 22;
    }
    if (!is_random_fallback_identifier(&fallbackNilFirst) ||
        !is_random_fallback_identifier(&fallbackNilSecond) ||
        !is_random_fallback_identifier(&fallbackEmpty) ||
        !is_random_fallback_identifier(&fallbackLong)) {
        return 23;
    }
    if (memcmp(fallbackNilFirst.identifier, fallbackNilSecond.identifier, fallbackNilFirst.identifierLength) == 0) {
        return 24;
    }
    return 0;
}
SOURCE

cc -Icore/include core/src/LHScope.c core/src/LHSeed.c "$tmpdir/seed_check.c" -o "$tmpdir/seed_check"
"$tmpdir/seed_check" >/dev/null
printf '%s\n' "seed derivation check passed"
