#!/bin/sh
set -eu

artifact=${1:?artifact path required}

if [ ! -f "$artifact" ]; then
  printf '%s\n' "missing artifact"
  exit 1
fi

if otool -L "$artifact" | grep -E 'libswift|Swift' >/dev/null; then
  printf '%s\n' "Swift runtime dependency found"
  otool -L "$artifact" | grep -E 'libswift|Swift'
  exit 1
fi

printf '%s\n' "Swift runtime absence passed"
