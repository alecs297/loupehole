#!/bin/sh
set -eu

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

if [ ! -f src/core/generated/LHGeneratedPolicySeeds.h ]; then
    printf '%s\n' 'Run make generate before routing-table-check.sh.' >&2
    exit 1
fi

"${CC:-cc}" \
    -std=c11 -Wall -Wextra -Werror \
    -fsanitize=address,undefined -fno-omit-frame-pointer \
    -Isrc/core/include -Isrc/core/generated -Isrc/mitigations \
    src/scripts/verify/fixtures/routing-table-check.c \
    src/runtime/hooks/LHHookBackend.c \
    src/runtime/seeds/LHSeed.c \
    src/mitigationkit/LHMitigationValues.c \
    src/core/generated/LHGeneratedPolicySeeds.c \
    -o "$tmpdir/routing-table-check"

"$tmpdir/routing-table-check"
