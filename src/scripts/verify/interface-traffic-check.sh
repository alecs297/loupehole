#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

"${CC:-cc}" -std=c11 -fblocks -Wall -Wextra -Werror \
  -fsanitize=address,undefined -fno-omit-frame-pointer \
  -I"$repo_root/src/core/include" -I"$repo_root/src/core/generated" \
  "$repo_root/src/scripts/verify/interface-traffic-check.c" \
  "$repo_root/src/mitigations/network/interface_inventory/RoutingTableMitigation.c" \
  "$repo_root/src/core/generated/LHGeneratedPolicySeeds.c" \
  "$repo_root/src/mitigationkit/LHMitigationValues.c" \
  "$repo_root/src/runtime/scope/LHScope.c" \
  "$repo_root/src/runtime/seeds/LHSeed.c" \
  "$repo_root/src/runtime/hooks/LHHookBackend.c" \
  -framework CoreFoundation -framework Network \
  -o "$tmpdir/interface-traffic-check"

"$tmpdir/interface-traffic-check"

# Exercise the actual module and backend against native imports in both formats.
for fixups in -no_fixup_chains -fixup_chains; do
  "${CC:-cc}" -std=c11 -fblocks -Wall -Wextra -Werror -Wl,"$fixups" \
    -I"$repo_root/src/core/include" -I"$repo_root/src/core/generated" \
    "$repo_root/src/scripts/verify/interface-traffic-live.c" \
    "$repo_root/src/mitigations/network/interface_inventory/RoutingTableMitigation.c" \
    "$repo_root/src/core/generated/LHGeneratedPolicySeeds.c" \
    "$repo_root/src/mitigationkit/LHMitigationValues.c" \
    "$repo_root/src/runtime/scope/LHScope.c" \
    "$repo_root/src/runtime/seeds/LHSeed.c" \
    "$repo_root/src/runtime/hooks/LHHookBackend.c" \
    -framework CoreFoundation -framework Network \
    -o "$tmpdir/interface-traffic-live"
  "$tmpdir/interface-traffic-live"
done
