# Profiles

Compiled cohort profile data lives behind the core profile boundary. The current
package policy treats the default profile as the inherited runtime behavior for
all targetable third-party app processes when the Settings default profile is enabled.
The package still installs with that default profile off, and per-bundle policy
rows can override it, including disabled rows for individual apps.
