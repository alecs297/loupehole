# Filters

`../runtime.plist` is the package injection filter. It intentionally contains an
empty `Bundles` allowlist so the rootless package starts with no global
injection.

The generated package installs `/var/jb/usr/bin/lhctl`, which can list, enable,
disable, toggle, or clear package policy entries and then recompute this filter.
When the default policy is off, the filter contains only explicitly enabled
bundle IDs. When the default policy is on, the filter uses `com.apple.UIKit` to
load into UIKit app processes without maintaining an installed-app bundle cache.
The runtime guard still excludes system bundle IDs, non-app processes, and
extensions before seed or hook setup.

Per-bundle policy rows override the default. That means a disabled row for one
bundle remains effective while the default profile stays on; the filter remains
the broad UIKit app-class filter, and that app exits as a runtime no-op. Future
preference UI work can write the same package policy.
