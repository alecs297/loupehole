# Cameras

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/CameraProvider.swift`

Loupe category: Cameras
Loupe tier: local capture-device discovery, with permission-adjacent stable
device identifiers
Permission required: camera capture requires Camera permission and
`NSCameraUsageDescription`; Loupe's provider performs discovery and does not
start capture
Primary relevance: camera hardware cohort, permissioned camera identifiers,
external/Continuity camera presence, and coherence with device model,
display/safe-area, AR, media capture, and hardware profile surfaces.

This page intentionally does not assign first-class mitigations to mostly
model-constant camera lineup, field-of-view, or camera capability surfaces.
Those values are high-value hardware classifiers, but they should move only as
part of a complete device profile. The sensitive exception to keep visible here
is `AVCaptureDevice.uniqueID`, especially for apps that already have camera
permission or otherwise receive stable capture-device identifiers.

## Official Links

- Apple AVFoundation `AVCaptureDevice`: <https://developer.apple.com/documentation/avfoundation/avcapturedevice>
- Apple AVFoundation `AVCaptureDevice.DiscoverySession`: <https://developer.apple.com/documentation/avfoundation/avcapturedevice/discoverysession>
- Apple AVFoundation `AVCaptureDevice.DeviceType`: <https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct>
- Apple AVFoundation `AVCaptureDevice.Position`: <https://developer.apple.com/documentation/avfoundation/avcapturedevice/position>
- Apple AVFoundation `AVCaptureDevice.uniqueID`: <https://developer.apple.com/documentation/avfoundation/avcapturedevice/uniqueid>
- Apple AVFoundation `AVCaptureDevice.init(uniqueID:)`: <https://developer.apple.com/documentation/avfoundation/avcapturedevice/init%28uniqueid%3A%29>
- Apple AVFoundation `AVCaptureDevice.Format.videoFieldOfView`: <https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/videofieldofview>
- Apple AVFoundation camera authorization `requestAccess(for:completionHandler:)`: <https://developer.apple.com/documentation/avfoundation/avcapturedevice/requestaccess%28for%3Acompletionhandler%3A%29>
- Apple bundle resource `NSCameraUsageDescription`: <https://developer.apple.com/documentation/bundleresources/information-property-list/nscamerausagedescription>

## Loupe Signals and Decisions

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `deviceCount` | `AVCaptureDevice.DiscoverySession(...).devices.count` | Camera capture permission is not requested by Loupe's provider | Passive local discovery, permission-adjacent | Exclude as first-class Cameras mitigation | High as a model classifier, but mostly a hardware/profile constant. Handle through coherent device-profile selection. |
| `cam.<index>.<deviceType>.type` | Each discovered `AVCaptureDevice` mapped to localized name, position, device type, and first format FOV on iOS | Camera capture permission is not requested by Loupe's provider | Passive local discovery, permission-adjacent | Exclude as first-class Cameras mitigation | High as a model classifier. Lens lineup, virtual cameras, front/back position, and FOV reveal the device family. |
| `cam.<index>.<deviceType>.uniqueID` | `AVCaptureDevice.uniqueID` | Treat as permission-adjacent; especially sensitive when a target app has Camera permission | Passive local discovery in Loupe; stable capture-device identifier surface for permitted camera apps | Include for documentation and future mitigation planning | Medium to high. Stable identifiers can link app sessions and expose external/Continuity devices; they must not be spoofed independently from the camera inventory. |

Loupe enumerates these device types:

- shared across platforms: built-in wide-angle camera, external camera,
  Continuity Camera
- iOS-specific: ultra-wide, telephoto, dual, dual-wide, triple, TrueDepth, and
  LiDAR depth cameras

For each discovered device, Loupe emits the localized name and position. On iOS
it also reports the first format's video field of view when available. It then
emits the device `uniqueID`.

## Permission and Activity Classification

The provider does not call `AVCaptureDevice.requestAccess`, does not start an
`AVCaptureSession`, and does not capture frames. In that narrow sense Loupe's
collection is local discovery rather than active camera use.

Camera capture itself is permissioned. Apps that use the camera must provide
`NSCameraUsageDescription` and obtain camera authorization before capture. For
Loupehole planning, treat camera discovery and camera capture as adjacent but
not identical surfaces:

- lineup and FOV are hardware-profile facts
- capture and frames are permissioned camera use
- `uniqueID` is a stable identifier concern, especially once an app is already
  authorized to use capture devices

If an OS version redacts or withholds a camera identifier before authorization,
mitigation should preserve that platform behavior. Do not make an unauthorized
app see a richer synthetic identifier than the real API would expose.

## Fingerprinting Value

Camera lineup is a strong device-model classifier. The number of devices,
available device types, front/back positions, virtual camera combinations,
TrueDepth/LiDAR presence, localized names, zoom/capability surfaces, and FOV
values can narrow the device to a small model cohort.

Those lineup and capability values are mostly not personal identifiers. They
are model constants. Spoofing them piecemeal is risky because camera hardware
must agree with model identifier, screen/safe-area, GPU/Metal, ARKit support,
Photo/EXIF behavior, capture formats, and real capture functionality.

`uniqueID` is different. Apple documents capture devices as having unique
identifiers that persist across app restarts and system reboots, and external
or Continuity cameras can add user-environment specificity. A stable
per-device identifier can link sessions, distinguish multiple cameras of the
same type, and expose attached hardware. This is the camera surface most worth
tracking separately from generic camera lineup.

## Mitigation Strategy Ideas

### Excluded Hardware Camera Profile

Do not build one-off mitigations for:

- camera count
- built-in camera lineup
- front/back position set
- wide/ultra-wide/telephoto/dual/triple/TrueDepth/LiDAR presence
- field of view
- zoom ranges, capture format lists, frame-rate ranges, depth support, or other
  mostly model-constant capabilities if future Loupe providers add them

If these values are spoofed, they should come from a complete device profile
selected from real hardware cohorts. The profile must align with:

- `hw.machine`, marketing model, CPU/RAM, GPU/Metal, and display traits
- safe-area/notch/Dynamic Island and front-camera expectations
- ARKit, depth, TrueDepth, LiDAR, and camera-format availability
- Photo metadata, camera capture behavior, and media export expectations
- WebKit/media-device surfaces if the target app can observe them

Pass through the real camera profile if the runtime cannot provide a coherent
replacement.

### `camera.unique_id`

Track `AVCaptureDevice.uniqueID` as the first camera-specific mitigation
candidate. Coverage should include:

- direct `AVCaptureDevice.uniqueID` property reads
- `AVCaptureDevice.init(uniqueID:)` lookups
- discovery-session device arrays that contain synthetic or wrapped devices
- any future helper that maps devices by unique ID

Compatibility default should pass through. Camera apps, scanners, conferencing
apps, AR apps, capture pipelines, and device-selection UIs may persist the
selected camera by unique ID.

Strict behavior can replace stable unique IDs with profile-scoped synthetic IDs
only when the complete camera inventory is controlled. The replacement must be
stable within the same scope, unique per synthetic camera, and accepted by any
lookup path the app uses. If `init(uniqueID:)` receives a synthetic ID, it must
return the matching synthetic device behavior or fail in the same way the
platform would fail for an unknown ID.

Do not derive readable IDs or names. Do not generate a unique synthetic ID per
app launch. Do not expose a synthetic external/Continuity camera unless the
profile also models its presence.

## Derivation and Coherence Considerations

Camera lineup values should be cohort static. Choose from real device profiles
rather than deriving each camera trait independently from a seed.

Camera `uniqueID` values, if spoofed, should be opaque, seed-derived, and scoped
to the selected camera profile. The mapping must be stable for the scope and
must preserve one-to-one relationships between:

```text
discovery device list
device type and position
localized name or generic profile label
uniqueID property
init(uniqueID:) lookup behavior
capture/session behavior for the selected device
```

External and Continuity cameras are live environment state. Avoid seed-derived
fake attached cameras unless the profile explicitly models a stable accessory.
For most strict privacy profiles, filtering external/Continuity cameras is safer
than inventing personalized synthetic devices.

Camera values must stay coherent with permissions. An unauthorized app should
not receive a more detailed synthetic capture profile than the platform would
normally expose without camera access.

## Impact and Tradeoffs

Changing camera lineup or capability values can break capture. Apps choose
devices by type, position, format, FOV, frame rate, depth support, and unique
ID. A synthetic profile that cannot actually capture with the advertised device
will fail quickly or produce obvious contradictions.

Changing `uniqueID` can break persisted camera selection. Users may have chosen
a front, back, external, or Continuity camera, and apps may restore that choice
by ID. If strict mode rewrites IDs, lookup and persistence behavior must be
covered too.

Leaving model-constant camera traits excluded from first-class mitigation keeps
scope controlled. It also avoids fragmented spoofing where camera lineup claims
one model while display, GPU, model identifier, AR support, and real capture
behavior reveal another.

## Exclusion Note

This category explicitly excludes mostly model-constant camera lineup,
field-of-view, and capability surfaces from standalone mitigation ownership.
They remain relevant to fingerprinting, but they belong in a coherent
hardware/device profile.

The tracked Cameras-specific mitigation candidate is `camera.unique_id`, because
stable capture-device identifiers can carry cross-session identity or attached
device context beyond ordinary model classification.

## Relevance

Cameras is relevant as a coherence dependency and as a permission-adjacent
identifier surface. The hardware lineup is high-value for device classification
but should be handled with model/profile work. `uniqueID` deserves separate
attention because it can link sessions and selected devices for apps that have
camera access or can observe stable capture-device identifiers.

Default behavior should pass through until a complete camera/device profile is
available. Strict behavior should start with `uniqueID` mapping and only later
consider full camera-profile substitution.
