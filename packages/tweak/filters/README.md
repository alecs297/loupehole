# Filters

`../runtime.plist` is the package injection filter. It intentionally contains an
empty `Bundles` allowlist so the rootless package starts with no global
injection.

The generated package installs `/var/jb/usr/bin/lhctl`, which can list, enable,
disable, toggle, or clear bundle IDs in this filter. The same helper also edits
the package-owned policy file for default and per-bundle mode, scope, and
mitigation-list settings. Future preference UI work can write the same package
policy while keeping the explicit allowlist model.
