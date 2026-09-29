#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
fixture_dir="$repo_dir/src/scripts/verify/fixtures"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT HUP INT TERM

cc -std=c11 -Wall -Wextra -Werror -g -fsanitize=address,undefined \
  -I"$repo_dir/src/core/include" \
  "$fixture_dir/imported-symbol-unit.c" -o "$tmpdir/unit"
"$tmpdir/unit"

cc -dynamiclib -Wall -Wextra -Werror \
  "$fixture_dir/imported-symbol-provider.c" \
  -Wl,-install_name,"$tmpdir/provider.dylib" -o "$tmpdir/provider.dylib"

for format in classic chained; do
  case "$format" in
    classic) fixups=-no_fixup_chains ;;
    chained) fixups=-fixup_chains ;;
  esac
  for lifetime in existing late; do
    cc -dynamiclib -O0 -Wall -Wextra -Werror \
      "$fixture_dir/imported-symbol-client.c" "$tmpdir/provider.dylib" \
      -Wl,"$fixups" -Wl,-install_name,"$tmpdir/$format-$lifetime.dylib" \
      -o "$tmpdir/$format-$lifetime.dylib"
  done
done

cc -std=c11 -Wall -Wextra -Werror -I"$repo_dir/src/core/include" \
  "$fixture_dir/imported-symbol-host.c" "$tmpdir/provider.dylib" \
  -o "$tmpdir/host"
"$tmpdir/host" "$tmpdir"
"$tmpdir/host" "$tmpdir" imports-only

printf '%s\n' 'Imported symbol checks passed (parsers, protections, classic/chained live images, late loads, hook composition).'
