# Bluetooth

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/BluetoothProvider.swift`

Loupe category: Bluetooth
Loupe tier: permissioned active BLE scan
Permission required: Bluetooth authorization and
`NSBluetoothAlwaysUsageDescription` on iOS privacy-managed paths
Primary relevance: nearby-device names, RSSI proximity, Bluetooth availability,
place/environment inference, accessory context, and coherence with audio,
location, network, and device-permission surfaces.

Loupe's Bluetooth provider reuses the `CBCentralManager` created by
`PermissionCenter`. If the central is unavailable or not powered on, Loupe emits
one placeholder signal. If Bluetooth is powered on, Loupe performs a five-second
BLE scan, records discovered peripheral names and RSSI values, then stops the
scan.

## Official Links

- [`CBCentralManager`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager)
- [`CBCentralManager.scanForPeripherals(withServices:options:)`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/scanforperipherals%28withservices%3Aoptions%3A%29)
- [`CBCentralManager.stopScan()`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/stopscan%28%29)
- [`CBCentralManagerDelegate`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerdelegate)
- [`centralManager(_:didDiscover:advertisementData:rssi:)`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerdelegate/centralmanager%28_%3Adiddiscover%3Aadvertisementdata%3Arssi%3A%29)
- [`CBPeripheral`](https://developer.apple.com/documentation/corebluetooth/cbperipheral)
- [`CBPeripheral.name`](https://developer.apple.com/documentation/corebluetooth/cbperipheral/name)
- [Core Bluetooth advertising data keys](https://developer.apple.com/documentation/corebluetooth/advertising-data)
- [`CBAdvertisementDataLocalNameKey`](https://developer.apple.com/documentation/corebluetooth/cbadvertisementdatalocalnamekey)
- [`CBCentralManagerScanOptionAllowDuplicatesKey`](https://developer.apple.com/documentation/corebluetooth/cbcentralmanagerscanoptionallowduplicateskey)
- [`CBManagerState`](https://developer.apple.com/documentation/corebluetooth/cbmanagerstate)
- [`CBManagerAuthorization`](https://developer.apple.com/documentation/corebluetooth/cbmanagerauthorization)
- [`NSBluetoothAlwaysUsageDescription`](https://developer.apple.com/documentation/bundleresources/information-property-list/nsbluetoothalwaysusagedescription)

## Loupe Signals

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `peripherals` with `Bluetooth unavailable` | `center.bluetoothCentral == nil` or `central.state != .poweredOn` | Bluetooth authorization/state-dependent | Passive permission/state placeholder | Include as state context, but not as a standalone device identifier | Low to medium. Powered-off, denied, restricted, unsupported, or unavailable Bluetooth state can reveal user policy and must match app-visible authorization/state. |
| `peripherals` with `None` | Five-second scan completed with no discovered peripherals | Bluetooth authorization required for scanning | Active local BLE scan | Include | Medium. An empty result still describes the immediate radio environment and permission/state behavior. |
| `peripherals` with names and RSSI | `scanForPeripherals(withServices:nil, options:[AllowDuplicates:false])`, `CBPeripheral.name`, `CBAdvertisementDataLocalNameKey`, fallback to `peripheral.identifier.uuidString`, and RSSI | Bluetooth authorization required for scanning | Active local BLE scan | Include | High. Nearby BLE names, fallback identifiers, and signal strength can reveal home/workplace, accessories, vehicles, medical devices, beacons, and proximity. |

Loupe stores one result per `CBPeripheral.identifier` and sorts the displayed
results by RSSI descending. It uses the peripheral name first, then the
advertised local name, and finally the peripheral identifier UUID string as a
fallback display label.

## Permission and Collection Class

This is an active permissioned scan, not a passive local read. Loupe calls
`scanForPeripherals(withServices:nil, options:)`, waits five seconds, then calls
`stopScan()`. The scan does not connect to peripherals and does not request
services, but it actively listens for nearby BLE advertisements.

The provider depends on Bluetooth privacy state through `PermissionCenter`'s
central manager. Mitigation must keep authorization, manager state, scan
callbacks, and placeholder values coherent. An app should not see denied
Bluetooth authorization while also receiving successful discovery callbacks.

No Camera, Microphone, Contacts, Local Network, Motion, Photos, or Location
permission is directly used by this provider. However, Bluetooth results can
reveal location-like context through nearby devices and beacons.

## Fingerprinting Value

Discovered peripheral names are the highest-value field. Personalized device
names, cars, watches, headphones, medical devices, hearing aids, fitness
equipment, smart-home accessories, keyboards, trackers, toys, and workplace
beacons can all identify a user or place. Even generic names become useful when
combined as a set.

RSSI adds proximity. It is noisy, but sorting by RSSI and recording signal
strength helps infer which devices are nearby, which are moving, and whether
the user is in a familiar physical environment. Repeated scans can link
sessions when the same devices appear with similar relative strength.

Fallback UUID strings are sensitive. If a peripheral has no name and Loupe
falls back to `peripheral.identifier.uuidString`, the output may become a stable
identifier for that central/peripheral relationship. Treat fallback IDs as
potentially higher risk than friendly names.

The unavailable and empty states have lower entropy, but they still matter.
Bluetooth off, denied, restricted, unsupported, or no nearby devices can explain
why scans fail and can become a policy/context signal.

## Mitigation Strategy Ideas

### `bluetooth.scan_results`

Cover the scan lifecycle and discovered results as one surface:

- `CBCentralManager.state`
- `CBManager.authorization` where available
- `scanForPeripherals(withServices:options:)`
- `stopScan()`
- `centralManager(_:didDiscover:advertisementData:rssi:)`
- `CBPeripheral.name`
- `CBPeripheral.identifier`
- `CBAdvertisementDataLocalNameKey`
- RSSI values delivered to discovery callbacks

Compatibility default should pass through. Bluetooth apps often need real
discovery for headphones, watches, health devices, medical sensors, keyboards,
trackers, smart-home devices, vehicle integrations, nearby-device setup, and
accessory management.

Strict behavior can return no peripherals, filter personalized names, or
coarsen RSSI. Returning an empty scan is safer than inventing fake nearby
devices. A synthetic device list can become a new identifier and can break apps
that attempt to connect.

### `bluetooth.names`

For apps that only display or log names, replace discovered names with generic
labels or hide the local-name key while preserving the existence of a device if
that is needed for compatibility. Do not generate seed-derived device names.
Names such as a unique "Headphones-8F3A" create a fresh cross-app identifier.

If a peripheral name is hidden, keep every path consistent: `CBPeripheral.name`,
advertisement local name, cached discovery results, and UI-facing wrappers
should not disagree.

### `bluetooth.identifiers_rssi`

Fallback identifiers and RSSI should be treated as sensitive. Strict mode can
drop unnamed peripherals rather than exposing UUID fallback labels. If an app
requires identifiers for connection, pass through or scope-map identifiers only
with full connection-path support.

RSSI should be coarse if exposed. Bucket values into broad proximity classes or
round to large intervals. Do not derive stable per-device RSSI values from the
instance seed; RSSI is live radio state and should remain noisy.

## Derivation Considerations

Bluetooth scan data is environment state, not stable user identity. Strict
profiles should prefer reduction over invention:

```text
authorization/state allows scanning only when callbacks can occur
empty scan means no discovery callbacks for that scan window
hidden names remain hidden in peripheral and advertisement paths
identifier mappings remain stable only within the intended scope
RSSI values are noisy and ordered consistently with displayed proximity
connection attempts agree with the discovered or filtered device list
```

If identifiers are mapped, the mapping must be opaque and scoped. It must also
cover any connection, service discovery, or restoration path the target app can
use. A scan-only ID rewrite that fails at connect time is easy to detect.

Bluetooth should stay coherent with nearby audio and accessory surfaces. For
example, reporting AirPods in the audio route while filtering all Bluetooth
peripherals may be plausible because connected devices are not always exposed
as BLE advertisements, but reporting a detailed BLE headset scan while Bluetooth
authorization is denied is not plausible.

Location-like coherence matters too. BLE beacons and named devices can imply a
home, car, gym, workplace, or clinic. Do not create synthetic nearby-device sets
that point to a rare or contradictory environment.

## Impact and Tradeoffs

Bluetooth mitigation can break real workflows quickly. Accessory discovery,
pairing, device setup, health devices, medical sensors, car integrations,
smart-home controls, trackers, nearby interactions, and device firmware tools
depend on accurate scan results.

Returning an empty scan is privacy-protective but can make an app appear broken.
Filtering names preserves some functionality but still leaks device presence.
Mapping identifiers requires broad coverage because apps may connect, discover
services, cache devices, or restore state by identifier.

RSSI coarsening has relatively low functional risk for simple display/logging
apps, but it can hurt proximity features. If an app uses RSSI for ranging or
selection, pass-through is safer.

## Relevance

Bluetooth is relevant because it is a permissioned but high-value environment
surface. A five-second scan can reveal nearby personal devices, place context,
and stable fallback identifiers. It is also a strong coherence dependency for
audio accessories, location-like context, and user permission posture.

Default behavior should be pass-through for apps with legitimate Bluetooth
needs. Strict profiles should start with empty or filtered scans for
fingerprinting-only apps, not with invented synthetic accessories.
