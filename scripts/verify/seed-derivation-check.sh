#!/bin/sh
set -eu

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/seed_check.c" <<'SOURCE'
#include "LHScope.h"
#include "LHSeed.h"

#include <stdio.h>
#include <string.h>

static int derive(const char *scopeText, unsigned char output[32]) {
    LHSeed seed;
    LHScope scope;
    if (!LHSeedParseUUID("123e4567-e89b-12d3-a456-426614174000", &seed)) {
        return 1;
    }
    if (!LHScopeInitPerApp(&scope, scopeText)) {
        return 2;
    }
    if (!LHSeedDeriveBytes(&seed, LHDerivationPurposeScopedSeed, &scope, output, 32)) {
        return 3;
    }
    return 0;
}

int main(void) {
    unsigned char first[32] = {0};
    unsigned char second[32] = {0};
    unsigned char other[32] = {0};

    if (derive("example.one", first) != 0) {
        return 1;
    }
    if (derive("example.one", second) != 0) {
        return 1;
    }
    if (derive("example.two", other) != 0) {
        return 1;
    }
    if (memcmp(first, second, sizeof(first)) != 0) {
        return 2;
    }
    if (memcmp(first, other, sizeof(first)) == 0) {
        return 3;
    }

    for (size_t i = 0; i < sizeof(first); i++) {
        printf("%02x", first[i]);
    }
    printf("\n");
    return 0;
}
SOURCE

cc -Icore/include core/src/LHScope.c core/src/LHSeed.c "$tmpdir/seed_check.c" -o "$tmpdir/seed_check"
"$tmpdir/seed_check" >/dev/null
printf '%s\n' "seed derivation check passed"
