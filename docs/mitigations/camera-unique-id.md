# `camera.unique_id`

The camera unique-ID option replaces stable `AVCaptureDevice` identifiers with scoped opaque IDs while preserving lookup for synthetic IDs where practical.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `camera.unique_id` |
| Implemented mitigation | `camera.unique_id.avcapturedevice.scoped_id` |
| Policy seeds | `camera_capture_device_unique_id` |
| User-facing name | Camera device identifiers |
| Status | Experimental |
| Surface | Cameras |
| Classification | Permission-adjacent stable identifier surface; active Objective-C hook mitigation |
| Affected APIs | `AVCaptureDevice.uniqueID`, `AVCaptureDevice.deviceWithUniqueID:` |
| Default behavior | Active when selected and allowed by runtime policy |
| Permission requirement | Discovery may be available without capture permission; capture remains permissioned |

## Surface And Relevance

Camera lineup and capabilities are mostly hardware-profile values and remain out of standalone scope. `AVCaptureDevice.uniqueID` is different: it can persist across launches, identify attached or Continuity cameras, and let apps restore selected capture devices.

## Mitigation Strategy

The mitigation hooks `-[AVCaptureDevice uniqueID]`, derives a 32-character lowercase hexadecimal ID from the real device ID, active seed, scope, and policy seed, and returns that synthetic value.

It also hooks `+[AVCaptureDevice deviceWithUniqueID:]`. If the original lookup fails, the replacement enumerates available devices, derives their synthetic IDs with the original `uniqueID` implementation, and retries the original lookup with the matching real ID.

This does not spoof camera count, device type, position, localized name, field of view, formats, frame rates, depth support, capture behavior, or permissions.

## Derivation And Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifier | `camera_capture_device_unique_id` |
| Generated seed symbol | `LHGeneratedPolicySeed_camera_capture_device_unique_id` |
| Helper | `LHMitigationDeriveBytes` with the real device ID as context |
| Value shape | 32 lowercase hexadecimal characters |
| Derivation input | active/practical seed + generated policy seed + active `LHScope` + original device ID context |
| Storage behavior | No mitigation-owned state blob |
| Lifetime | Stable until active seed, scope, policy seed, or the real camera inventory changes |

## Impact And Tradeoffs

Changing camera unique IDs can break persisted camera selection, but the lookup bridge handles apps that pass the synthetic ID back through `deviceWithUniqueID:`. Apps that compare unique IDs with unhooked camera metadata or cache devices before hook installation may still observe gaps.

## Validation

Repository-level validation is pending until the catalog and default selection are merged. Expected observations:

- `AVCaptureDevice.uniqueID` returns a scoped opaque value, not the real stable identifier.
- Repeated reads for the same device, seed, and scope return the same value.
- `deviceWithUniqueID:` accepts a synthetic ID after the device list can be enumerated.
- Camera lineup and permission behavior remain real.

## Rollback And Pass-Through

If derivation fails, the hook returns the original unique ID. If lookup mapping cannot enumerate devices or find a synthetic match, `deviceWithUniqueID:` preserves the platform result for the supplied ID.
