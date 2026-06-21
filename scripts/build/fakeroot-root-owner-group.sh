#!/bin/sh
set -eu

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
