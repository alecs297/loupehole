#!/bin/sh
set -eu

# Theos calls this wrapper in place of dpkg-deb so local package builds do not
# need fakeroot just to produce root-owned archive metadata.
exec dpkg-deb --root-owner-group "$@"
