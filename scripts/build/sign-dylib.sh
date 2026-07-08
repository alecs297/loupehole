#!/bin/sh
set -eu

# Sign a built dylib and verify that ldid can read the resulting entitlement
# state. Keep this script tiny so Makefile signing behavior stays obvious.
artifact=${1:?artifact path required}

if [ ! -f "$artifact" ]; then
  printf '%s\n' "missing artifact"
  exit 1
fi

ldid -S "$artifact"
ldid -e "$artifact" >/dev/null
