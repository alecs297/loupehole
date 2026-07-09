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

if grep -E 'Loupehole|loupehole|docs/|README|implementation-checklist|spoofing-option-policy|src/core|src/packaging/theos' "$tmp" >/dev/null; then
  printf '%s\n' "string scan failed"
  grep -E 'Loupehole|loupehole|docs/|README|implementation-checklist|spoofing-option-policy|src/core|src/packaging/theos' "$tmp"
  exit 1
fi

printf '%s\n' "string scan passed"
