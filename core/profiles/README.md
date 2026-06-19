# Profiles

Compiled cohort profile data lives behind the core profile boundary. The current
default runtime profile is minimal metadata for the first mitigation group; the
package policy decides where that profile applies.

For rootless packages, the default profile represents all discovered third-party
installed app bundles as a group. It is disabled on install. When enabled,
`lhctl` materializes the positive loader filter from third-party app containers,
excludes system bundle identifiers, and then applies per-bundle policy
overrides. The package's separate `installd` refresh trigger can keep that
materialized list current after app install-service notifications, but manual
`lhctl refresh` remains the compatibility fallback.
