# `bluetooth.corebluetooth`

This option suppresses Core Bluetooth scan result creation and sanitizes direct peripheral name and identifier reads.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `bluetooth.corebluetooth` |
| Implemented mitigation | `bluetooth.corebluetooth.scan.empty` |
| Policy seeds | `bluetooth_peripheral_identifier` |
| User-facing name | Bluetooth scans |
| Status | Experimental |
| Surface | Bluetooth |
| Classification | Active radio discovery surface; active Objective-C hook mitigation |
| Affected APIs | `CBCentralManager.scanForPeripherals(withServices:options:)`, `CBCentralManager.isScanning`, `CBPeripheral.name`, `CBPeripheral.identifier` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | Bluetooth authorization is required for normal scan behavior |

## References

- Apple Developer: `CBCentralManager`.
- Apple Developer: `CBCentralManager.scanForPeripherals(withServices:options:)`.
- Apple Developer: `CBCentralManager.isScanning`.
- Apple Developer: `CBPeripheral.name`.
- Apple Developer: `CBPeripheral.identifier`.

## Surface And Relevance

BLE scans expose nearby personal devices, beacons, vehicles, medical accessories, workplace equipment, fallback UUIDs, and RSSI proximity. Peripheral names and identifiers can be highly identifying.

## Mitigation Strategy

The module uses a strict empty-scan posture:

- `scanForPeripheralsWithServices:options:` is converted to a no-op;
- `isScanning` reports `NO`;
- `CBPeripheral.name` returns `nil`;
- `CBPeripheral.identifier` maps the original UUID to a scoped synthetic UUID when a peripheral object is available from another path.

It does not alter Bluetooth authorization, manager state, or connection behavior.

## Derivation And Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifier | `bluetooth_peripheral_identifier` |
| Generated seed symbol | `LHGeneratedPolicySeed_bluetooth_peripheral_identifier` |
| Helper | `LHMitigationDeriveBytes` with the original peripheral UUID bytes as context |
| Value shape | RFC 4122 version 4 `NSUUID` for covered peripheral identifier reads |
| Derivation input | active/practical seed + generated policy seed + active `LHScope` + original peripheral UUID context |
| Storage behavior | No mitigation-owned state blob |
| Lifetime | Mapped identifiers are stable until active seed, scope, policy seed, or the original peripheral identifier changes |

## Impact And Tradeoffs

This is intentionally strict and can make Bluetooth discovery, pairing, accessory setup, health devices, smart-home devices, trackers, and firmware tools appear broken. It is safer than inventing fake nearby devices, but it sacrifices scan compatibility.

Advertisement dictionaries, RSSI callback values, service discovery, restoration identifiers, connection flows, and retrieve-by-identifier paths are not fully covered. Because mapped identifiers are not accepted by Core Bluetooth retrieve/connect APIs, apps that feed the synthetic UUID back into the framework may observe a mismatch.

## Validation

Expected observations after integration:

- new scans produce no discovery callbacks from the hooked scan method;
- `isScanning` remains false;
- direct peripheral names are nil;
- direct peripheral identifiers are scoped synthetic UUIDs when a peripheral reaches the app by another route.

## Rollback And Pass-Through

If Core Bluetooth classes or all selected selectors are unavailable, the module registers as a no-op. Identifier mapping falls back to the original UUID if derivation or UUID construction fails. Disabling the mitigation restores original Core Bluetooth behavior on these covered selectors.
