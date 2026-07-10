#!/bin/sh
set -eu

artifact=${1:?artifact path required}

if [ ! -f "$artifact" ]; then
  printf '%s\n' "missing artifact"
  exit 1
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

strings -a "$artifact" >"$tmp"

if grep -E 'NSLog|os_log|os_log_create|printf|fprintf|diagnostic|debug' "$tmp" >/dev/null; then
  printf '%s\n' "debug log scan failed"
  grep -E 'NSLog|os_log|os_log_create|printf|fprintf|diagnostic|debug' "$tmp"
  exit 1
fi

printf '%s\n' "debug log absence passed"
