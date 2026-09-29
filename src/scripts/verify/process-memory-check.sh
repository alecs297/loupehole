#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

# Native Darwin headers exercise the Mach ABI without an iOS device or generator.
"${CC:-cc}" -std=c11 -Wall -Wextra -Werror \
  -fsanitize=address,undefined -fno-omit-frame-pointer \
  -I"$repo_root/src/scripts/verify/process-memory-fixtures" \
  -I"$repo_root/src/core/include" \
  "$repo_root/src/scripts/verify/process-memory-check.c" \
  "$repo_root/src/mitigationkit/LHMitigationValues.c" \
  "$repo_root/src/runtime/seeds/LHSeed.c" \
  "$repo_root/src/runtime/hooks/LHHookBackend.c" \
  -o "$tmpdir/process-memory-check"

"$tmpdir/process-memory-check"
