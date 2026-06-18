# Filters

`../runtime.plist` is the first package filter. It intentionally contains an
empty `Bundles` allowlist so the rootless package starts with no global
injection. The generated package installs `/var/jb/usr/bin/lhctl`, which can
list, enable, disable, toggle, or clear bundle IDs in this filter. Future
configuration work can replace that first CLI helper with a richer preference
provider while keeping the same explicit allowlist model.
