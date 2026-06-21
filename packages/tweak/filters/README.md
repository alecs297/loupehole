# Filters

`../Filter.plist` is the source template for the package injection filter. The
rootless package installs it next to the tweak dylib as
`<generated-loader-basename>.plist`, with the same generated basename as the
dylib. The template intentionally contains an empty `Bundles` allowlist so the
rootless package starts with no global injection.

The generated package installs `LoupeholePreferences.bundle`, whose Settings
store edits package policy entries and recomputes this filter. When the default
policy is off, the filter contains only explicitly enabled bundle IDs. When the
default policy is on, the filter uses `com.apple.UIKit` to load into UIKit app
processes without maintaining an installed-app bundle cache. The runtime guard
still excludes system bundle IDs, non-app processes, and extensions before seed
or hook setup.

Per-bundle policy rows override the default. That means a disabled row for one
bundle remains effective while the default profile stays on; the filter remains
the broad UIKit app-class filter, and that app exits as a runtime no-op.
