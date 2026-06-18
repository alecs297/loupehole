#!/bin/sh
set -eu

artifact=${1:?artifact path required}

if [ ! -f "$artifact" ]; then
  printf '%s\n' "missing artifact"
  exit 1
fi

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

nm -gmU "$artifact" >"$tmp" || true

if [ -s "$tmp" ]; then
  printf '%s\n' "exported symbol scan failed"
  cat "$tmp"
  exit 1
fi

printf '%s\n' "exported symbol scan passed"
