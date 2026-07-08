# Graphics & Metal Fingerprint Category

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/MetalProvider.swift`

Loupe category: Graphics & Metal
Loupe tier: passive hardware/cohort profile
Permission required: none
Primary relevance: GPU/SoC generation, graphics capability cohort, WebGL/canvas
coherence, display profile coherence, and simulator/device detection.

Loupe calls `MTLCreateSystemDefaultDevice()` and reads properties from the
default `MTLDevice`. These values are app-readable without a prompt, but they
are mostly hardware constants. This page documents them as coherence constraints
for a complete device and graphics profile rather than as independent
one-off spoofing targets.

## Official Links

- Apple Metal `MTLCreateSystemDefaultDevice()`: <https://developer.apple.com/documentation/metal/mtlcreatesystemdefaultdevice%28%29>
- Apple Metal `MTLDevice`: <https://developer.apple.com/documentation/metal/mtldevice>
- Apple Metal `MTLDevice.name`: <https://developer.apple.com/documentation/Metal/MTLDevice/name>
- Apple Metal `MTLDevice.recommendedMaxWorkingSetSize`: <https://developer.apple.com/documentation/metal/mtldevice/recommendedmaxworkingsetsize>
- Apple Metal `MTLDevice.supportsRaytracing`: <https://developer.apple.com/documentation/metal/mtldevice/supportsraytracing>
- Apple Metal `MTLDevice.supportsFamily(_:)`: <https://developer.apple.com/documentation/metal/mtldevice/supportsfamily%28_%3A%29>
- Apple Metal `MTLGPUFamily`: <https://developer.apple.com/documentation/metal/MTLGPUFamily>
- Apple Metal device inspection: <https://developer.apple.com/documentation/metal/device-inspection>
- Apple Metal Feature Set Tables: <https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf>

Apple documents the Metal device and GPU-family inspection APIs directly. The
feature-set tables are the practical equivalent reference for mapping Metal
families and capabilities to supported Apple GPU generations.

## Loupe Signals and Decisions

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `unavailable` | Placeholder when `MTLCreateSystemDefaultDevice()` returns `nil` | None | Passive environment/simulator placeholder | Exclude | Not a stable hardware value. It mainly indicates simulator, unsupported environment, policy failure, or missing Metal device. |
| `name` | `MTLDevice.name` | None | Passive hardware capability read | Exclude as standalone mitigation; keep as GPU profile constraint | High. The GPU name is a near-direct SoC/device generation classifier and must agree with model, CPU, WebGL renderer, canvas, and OS claims. |
| `recommendedMax` | `MTLDevice.recommendedMaxWorkingSetSize`, formatted with `ByteCountFormatter` | None | Passive hardware/memory capability read | Exclude as standalone mitigation; keep as GPU/RAM profile constraint | Medium to high. Reveals GPU memory budget and device tier; useful when joined with RAM, SoC, model, and graphics workload behavior. |
| `raytracing` | `MTLDevice.supportsRaytracing` | None | Passive graphics capability read | Exclude as standalone mitigation; keep as GPU generation constraint | High when true. Hardware ray tracing support narrows the Apple GPU generation and must agree with Metal family, model, and WebGL behavior. |
| `families` | `supportsFamily(_:)` for `.apple1` through `.apple9`, `.common1` through `.common3`, and `.metal3` | None | Passive feature-family inventory | Exclude as standalone mitigation; keep as GPU feature-set constraint | High. The supported family set is a compact GPU generation and OS capability signature. |

Loupe emits `families` as a comma-separated value and as tag entries. The
provider currently checks a fixed family list through `apple9`, `common3`, and
`metal3`; newer Apple SDKs may add future families that Loupe does not yet
query.

## Permission and Activity Classification

No Graphics & Metal signal requires Contacts, Location, Bluetooth, Motion,
Photos, Local Network, Camera, Microphone, or another user-granted runtime
permission. Metal device inspection is app-readable.

Collection is passive in Loupe's current implementation. It creates or fetches
the default Metal device object and reads capability properties. It does not
compile shaders, allocate workloads, render frames, benchmark the GPU, access a
display, or send network traffic.

The mitigation side can be active and risky even though collection is passive.
Intercepting Metal device creation or capability calls affects real rendering,
compute, games, camera pipelines, ML acceleration, image processing, WebKit, and
frameworks that use Metal internally.

## Fingerprinting Value

`name` is the strongest single signal. On Apple platforms, the Metal device name
often maps closely to an SoC generation or GPU family. A tracker can compare it
with `hw.machine`, marketing model, CPU count, RAM tier, camera lineup, display
capabilities, WebGL renderer, and canvas behavior.

`families` is at least as important as the name for detection. GPU family
support encodes both hardware and OS/SDK capability exposure. A profile that
claims an older GPU name while supporting newer Apple GPU families, or claims a
new model while missing the expected family set, is easy to flag.

`supportsRaytracing` is a high-value boolean because `true` is limited to newer
GPU cohorts. It is also hard to fake safely because apps may enable different
rendering paths, shaders, acceleration structures, or feature gates based on the
answer.

`recommendedMax` contributes memory-tier entropy. The formatted value is not
usually unique alone, but it helps separate device classes and must agree with
physical memory, model generation, and real Metal allocation behavior.

`unavailable` is fingerprinting-relevant mainly as environment detection. In a
real iOS device process, no default Metal device may indicate simulator,
restricted platform behavior, or an unusual failure state. It should not be
turned into a synthetic identity value.

## Mitigation Strategy Ideas

### `graphics.gpu_profile`

Do not spoof individual Metal properties independently. A Metal profile should
be a real-device tuple selected from a small cohort table:

- Metal device name
- supported `MTLGPUFamily` set
- raytracing support
- recommended max working set size range
- model identifier, SoC, CPU count, RAM tier, display profile, and OS version
- WebKit WebGL renderer and canvas behavior

Compatibility default should pass through. Metal capabilities drive real code
paths and performance decisions. A mismatched fake value can make an app choose
unsupported shaders, memory budgets, raytracing pipelines, or feature paths.

Strict mode should only return a synthetic tuple when the selected tuple is
known to be compatible with the actual device or when the hook can safely
prevent unsupported feature use. For most devices, downshifting to a lower
capability cohort is safer than upshifting to features the hardware cannot
provide.

### `graphics.metal_device_identity`

If a target app reads only `MTLDevice.name`, normalization can replace personal
or overly precise naming with a cohort value, but that value must still match
the family and capability answers. Do not return a name like a newer Apple GPU
while leaving old `supportsFamily(_:)` results visible.

Coverage should include wrappers and cache points around `MTLCreateSystemDefaultDevice()`
and the returned device object's property methods. If an app caches the original
device before hooks are active, later property spoofing can become inconsistent.

### `graphics.metal_feature_set`

Treat `supportsFamily(_:)`, `supportsRaytracing`, and future feature/capability
methods as one graph. A strict profile can deny newer feature families to reduce
entropy, but it must account for app behavior that follows from denial:
fallback rendering paths, disabled visual effects, missing GPU features, and
performance differences.

Avoid claiming support for any feature the real GPU cannot execute. False
positive capabilities can crash apps, produce rendering bugs, or expose the
mitigation when pipeline creation fails after capability checks said it should
succeed.

### `graphics.working_set`

`recommendedMaxWorkingSetSize` should be generated from the selected GPU and RAM
profile, not as a free number. If strict mode reduces memory entropy, prefer a
common cohort value for the selected real-device profile. Keep the formatted
value and raw byte value consistent wherever the app can read both.

Do not return a high working-set budget on a low-memory device. Apps may use the
value to size caches, textures, heaps, or compute buffers, and unrealistic values
can cause memory pressure or crashes.

## Derivation and Coherence Considerations

Graphics values should be cohort static. They are not good candidates for
per-user random derivation because valid combinations are tightly constrained by
Apple hardware and OS releases. The generator should choose from known plausible
profiles, not build a GPU by hashing the seed into independent fields.

A coherent graphics profile should include:

```text
model identifier and marketing class
SoC / CPU generation and physical memory tier
Metal device name and supported GPU families
raytracing and other feature-gate booleans
recommended working-set size
display metrics, color capability, and maximum refresh behavior
WebKit WebGL renderer, canvas rendering behavior, and WebView screen claims
OS and WebKit version compatibility
```

If the hardware profile is not active or cannot supply a coherent tuple, pass
through Metal values. Partial spoofing is especially visible in this category
because apps can combine property checks with actual rendering, shader feature
use, timing, memory pressure, and WebKit results.

Profile labels, derivation salts, and mitigation names must stay internal and
seed-bound. Returned Metal strings should look like platform values, not
Loupehole identifiers or readable policy names.

The `unavailable` state should not be seed-derived. It should reflect the real
environment or an explicit policy decision to deny Metal availability for a
target process. If Metal is denied, WebGL, canvas, rendering performance, and
app feature availability must reflect that denial too.

## Impact and Tradeoffs

Metal spoofing has high compatibility risk. Apps use Metal capabilities for
rendering engines, games, maps, camera processing, ML/compute workloads, video
effects, image editors, AR, and WebKit internals. A fake capability can lead to
unsupported pipelines, crashes, rendering corruption, memory pressure, or severe
performance regressions.

Downshifting capabilities can improve privacy but may visibly degrade graphics,
disable features, lower frame rates, or push apps onto CPU fallback paths.
Upshifting is usually unsafe because the real GPU cannot provide missing
features.

Working-set spoofing can alter memory allocation decisions. Too high a value
can cause memory pressure; too low a value can make apps reduce quality, shrink
caches, or take slow paths.

Leaving Metal signals out of standalone mitigation scope reduces immediate
implementation surface, but it does not lower their fingerprinting importance.
It forces the right architecture: Metal should move only as part of a coherent
hardware/graphics profile that can also explain WebGL, canvas, display, model,
and OS values.

## Exclusion Note

Per user rule and the fingerprint inventory inclusion rule, this page excludes
these hardware-constant Metal values from first-class standalone mitigation:

- `name`
- `recommendedMax`
- `raytracing`
- `families`

The `unavailable` placeholder is also excluded because it is an environment or
failure state rather than a stable fingerprint value to synthesize.

These exclusions do not mean the signals are unimportant. They are high-value
fingerprinting and detection signals, but they should be owned by a complete
hardware/graphics profile. That profile must align GPU/Metal, WebGL, canvas,
screen/display, CPU, RAM, model identifier, camera lineup, OS, and WebKit values
instead of spoofing one Metal property at a time.

## Relevance

Graphics & Metal is a P0 coherence category even if it is not a good standalone
mitigation category. Metal exposes a compact view of the real hardware cohort,
and target apps can compare it against native device identity, WebView WebGL,
canvas hashes, display constants, CPU/RAM, and actual rendering behavior.

For near-term Loupehole work, this page should feed the future device-profile
generator and WebView graphics mitigation notes. The safest current default is
pass-through unless a complete and tested hardware/graphics profile is selected.
