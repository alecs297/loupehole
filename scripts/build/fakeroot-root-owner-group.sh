#!/bin/sh
set -eu

# Minimal fakeroot-compatible shim for Theos package invocations. Package
# ownership is handled by dpkg-deb --root-owner-group, so faked is unnecessary.
while [ "$#" -gt 0 ]; do
  case "$1" in
    -p)
      shift 2
      ;;
    -c)
      exit 0
      ;;
    -r)
      shift
      exec "$@"
      ;;
    *)
      exec "$@"
      ;;
  esac
done
