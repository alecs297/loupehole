# `camera.unique_id`

The camera unique-ID option passes built-in and unknown `AVCaptureDevice` identifiers through, and only replaces identifiers for devices the platform explicitly classifies as external or Continuity cameras.

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
| Default behavior | Active when selected and allowed by runtime policy; built-in and unknown cameras pass through |
| Permission requirement | Discovery may be available without capture permission; capture remains permissioned |

## Surface And Relevance

Camera lineup and capabilities are mostly hardware-profile values and remain out of standalone scope. Built-in camera unique IDs are part of that coherent hardware profile and pass through. External and Continuity camera IDs are different: they can persist across launches, identify attached user-environment devices, and let apps restore selected capture devices.

## Mitigation Strategy

The mitigation hooks `-[AVCaptureDevice uniqueID]`. For built-in cameras, unknown device types, and devices that cannot be classified safely, it returns the original unique ID. For devices where `AVCaptureDevice.deviceType` is explicitly external or Continuity, or `isContinuityCamera` reports true, it derives a 32-character lowercase hexadecimal ID from the real device ID, active seed, scope, and policy seed.

It also hooks `+[AVCaptureDevice deviceWithUniqueID:]`. If the original lookup fails, the replacement enumerates available devices, derives synthetic IDs only for external/Continuity devices with the original `uniqueID` implementation, and retries the original lookup with the matching real ID.

This does not spoof camera count, device type, position, localized name, field of view, formats, frame rates, depth support, capture behavior, or permissions. It does not hide that an external or Continuity camera exists; it only reduces exposure of that camera's stable unique identifier on covered API paths.

## Derivation And Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifier | `camera_capture_device_unique_id` |
| Generated seed symbol | `LHGeneratedPolicySeed_camera_capture_device_unique_id` |
| Helper | `LHMitigationDeriveBytes` with the real device ID as context |
| Value shape | Original ID for built-in/unknown cameras; 32 lowercase hexadecimal characters for external/Continuity cameras |
| Derivation input | active/practical seed + generated policy seed + active `LHScope` + original external/Continuity device ID context |
| Storage behavior | No mitigation-owned state blob |
| Lifetime | Built-in IDs retain platform lifetime; synthetic external/Continuity IDs are stable until active seed, scope, policy seed, or the real camera inventory changes |

## Impact And Tradeoffs

Changing camera unique IDs can break persisted camera selection, so the mitigation avoids built-in cameras and unknown devices. The lookup bridge handles apps that pass a synthetic external/Continuity ID back through `deviceWithUniqueID:`. Apps that compare unique IDs with unhooked camera metadata, cache devices before hook installation, or inspect external-camera presence through names, types, formats, or capture behavior may still observe gaps.

## Validation

Repository-level validation is pending until the catalog and default selection are merged. Expected observations:

- Built-in and unknown `AVCaptureDevice.uniqueID` values pass through unchanged.
- Explicit external/Continuity devices return a scoped opaque value, not the real stable identifier.
- Repeated reads for the same external/Continuity device, seed, and scope return the same value.
- `deviceWithUniqueID:` accepts a synthetic external/Continuity ID after the device list can be enumerated.
- Camera lineup and permission behavior remain real.

## Rollback And Pass-Through

If classification or derivation fails, the hook returns the original unique ID. If lookup mapping cannot enumerate devices or find a synthetic match, `deviceWithUniqueID:` preserves the platform result for the supplied ID.
