#!/bin/sh
set -eu

artifact=${1:?artifact path required}

if [ ! -f "$artifact" ]; then
  printf '%s\n' "missing artifact"
  exit 1
fi

file "$artifact"
otool -hv "$artifact"
otool -L "$artifact"
printf '%s\n' "signing:"
ldid -e "$artifact" >/dev/null
printf '%s\n' "ldid readable"
