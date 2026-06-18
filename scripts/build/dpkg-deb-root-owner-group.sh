#!/bin/sh
set -eu

exec dpkg-deb --root-owner-group "$@"
