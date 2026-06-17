# Loupehole

Loupehole is a planned privacy-preserving iOS tweak/library that reduces abusive fingerprinting from native apps and embedded web views. The project is currently in planning mode. The initial scope is based on the public surfaces demonstrated by [mysk-research/loupe](https://github.com/mysk-research/loupe), plus adjacent iOS fingerprinting techniques that are not yet covered by Loupe.

The central design principle is not "make every device random." The safer target is to make protected apps see a coherent, common, low-entropy device profile. A per-user random pile of values is easy to recognize as synthetic and can become a stronger fingerprint than the real device.

## Documents

- [Execution plan](docs/execution-plan.md): goals, roadmap, milestones, development environment, risk model, and release tracks.
- [Architecture](docs/architecture.md): proposed repository layout, tweak runtime, build system, configuration model, website/custom compiler, and QA harness.
- [Implementation checklist](docs/implementation-checklist.md): actionable phase-by-phase handoff plan with statuses and acceptance checks.
- [Fingerprinting surfaces](docs/fingerprinting-surfaces.md): detailed API-by-API notes, mitigation strategy, limitations, and priority.
- [Spoofing option policy](docs/spoofing-option-policy.md): non-identifying constants, common defaults, required option documentation, and mitigation method coverage.
- [Research notes](docs/research-notes.md): source inventory, Loupe upstream commit, and open research questions.

## Development Environment

The canonical local build environment is macOS with Xcode, Theos, `ldid`, `dpkg-deb`, and `fakeroot`. Development should start with a plain injectable `.dylib`, then wrap the same runtime in a rootless `.deb` once the hook and policy boundaries are stable. Real-device deployment and validation are intentionally out of band: the artifact may be injected into an owned app through Sideloadly or another sideloaded/test flow, or installed as a jailbreak package.

Package work must support clean install, upgrade, disable, and uninstall paths. The `.deb` must remove or neutralize installed dynamic libraries, filter plists, preference bundles, launch helpers, generated caches, and package-owned configuration without touching protected app data unless the user explicitly chose that cleanup.

## Non-goals

- No shipping invasive anti anti-jailbreak tweaks, the aim of the project is to combat fingerprinting in an effective way, not evade DRMs.
- No telemetry collection by the tweak or build website.

The project can still reduce self-fingerprinting by avoiding stable public markers, minimizing exported symbols, keeping runtime side effects low, and offering build variability. That is different from promising to defeat every app's tamper detection.

The injected tweak must not contain hardcoded values that identify the project or a specific build. Common spoofed defaults are allowed only as profile data when they plausibly appear on normal devices and are shared by many users.
