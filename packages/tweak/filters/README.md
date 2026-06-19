# Filters

`../runtime.plist` is the package injection filter. It intentionally contains an
empty `Bundles` allowlist so the rootless package starts with no global
injection.

The generated package installs `/var/jb/usr/bin/lhctl`, which materializes this
positive `Bundles` list from package policy. The default profile is device-wide
for discovered third-party installed app bundles, but it is disabled on install.
When the default is enabled, `lhctl` refreshes the filter from third-party app
containers and excludes system bundle identifiers. Per-bundle overrides can
enable one app while the default is off, or disable one app while the default is
on.

The package also includes `installrefresh.plist`, which targets the
`installrefresh.dylib` trigger to the `installd` executable only. That trigger
does not load the privacy runtime into SpringBoard. It only asks `lhctl
refresh-auto` to refresh this materialized app allowlist after matching
install-service notifications, and `refresh-auto` does nothing unless the
default profile is enabled.

The same helper edits the package-owned policy file for default and per-bundle
enabled state, scope, and mitigation-list settings. Future preference UI work
can write the same package policy while keeping the materialized allowlist model.
