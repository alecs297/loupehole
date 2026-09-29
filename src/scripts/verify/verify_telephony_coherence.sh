#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/CoreTelephony"
cp "$repo_root/src/scripts/verify/verify_telephony_sdk.h" "$tmpdir/CoreTelephony/CTTelephonyNetworkInfo.h"

cc -fblocks -Wall -Wextra -Werror \
  -I"$tmpdir" -I"$repo_root/src/scripts/verify/telephony-fixtures" -I"$repo_root/src/core/include" \
  "$repo_root/src/scripts/verify/verify_telephony_coherence.m" \
  "$repo_root/src/runtime/hooks/LHHookBackend.c" \
  -framework Foundation -o "$tmpdir/verify_telephony_coherence"

"$tmpdir/verify_telephony_coherence"
"$tmpdir/verify_telephony_coherence" partial-services
"$tmpdir/verify_telephony_coherence" partial-carrier
"$tmpdir/verify_telephony_coherence" partial-notifier
"$tmpdir/verify_telephony_coherence" no-hooks

xcrun --sdk iphoneos clang -target arm64-apple-ios15.0 -fsyntax-only -Wall -Wextra -Werror \
  -I"$repo_root/src/scripts/verify/telephony-fixtures" -I"$repo_root/src/core/include" \
  "$repo_root/src/mitigations/telephony/radio_access/TelephonyRadioProfileMitigation.m"
printf '%s\n' 'telephony coherence check passed (host fixtures and iOS SDK syntax)'
