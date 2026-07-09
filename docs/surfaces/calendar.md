# Calendar

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/CalendarProvider.swift`

Loupe category: Calendar
Loupe tier: permissioned local EventKit inventory and event-count query, with
active one-shot calendar-store reads after user grant
Permission required: Calendar full access through `EKEventStore`; Loupe declares
`NSCalendarsFullAccessUsageDescription` and requests full event access before
collection.
Primary relevance: calendar account topology, provider names, calendar types,
routine density, and post-permission privacy impact.

This category covers metadata Loupe derives from EventKit calendars and a
60-day event window centered on the current date. Loupe does not display event
titles, notes, attendees, locations, or calendar titles, but it does request
full access to event data and uses EventKit queries that can return event
objects in order to count them.

## Official Links

- [`EventKit`](https://developer.apple.com/documentation/eventkit)
- [`EKEventStore`](https://developer.apple.com/documentation/eventkit/ekeventstore)
- [`EKEventStore.authorizationStatus(for:)`](https://developer.apple.com/documentation/eventkit/ekeventstore/authorizationstatus%28for%3A%29)
- [`EKEventStore.requestFullAccessToEvents(completion:)`](https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoevents%28completion%3A%29)
- [`EKEventStore.requestWriteOnlyAccessToEvents(completion:)`](https://developer.apple.com/documentation/eventkit/ekeventstore/requestwriteonlyaccesstoevents%28completion%3A%29)
- [`NSCalendarsFullAccessUsageDescription`](https://developer.apple.com/documentation/bundleresources/information-property-list/nscalendarsfullaccessusagedescription)
- [`NSCalendarsWriteOnlyAccessUsageDescription`](https://developer.apple.com/documentation/bundleresources/information-property-list/nscalendarswriteonlyaccessusagedescription)
- [TN3152: Migrating to the latest Calendar access levels](https://developer.apple.com/documentation/technotes/tn3152-migrating-to-the-latest-calendar-access-levels)
- [`EKEventStore.calendars(for:)`](https://developer.apple.com/documentation/eventkit/ekeventstore/calendars%28for%3A%29)
- [`EKCalendar`](https://developer.apple.com/documentation/eventkit/ekcalendar)
- [`EKCalendar.source`](https://developer.apple.com/documentation/eventkit/ekcalendar/source)
- [`EKSource.title`](https://developer.apple.com/documentation/eventkit/eksource/title)
- [`EKCalendar.type`](https://developer.apple.com/documentation/eventkit/ekcalendar/type)
- [`EKEventStore.predicateForEvents(withStart:end:calendars:)`](https://developer.apple.com/documentation/eventkit/ekeventstore/predicateforevents%28withstart%3Aend%3Acalendars%3A%29)
- [`EKEventStore.events(matching:)`](https://developer.apple.com/documentation/eventkit/ekeventstore/events%28matching%3A%29)

Apple's newer EventKit model separates write-only calendar access from full
event access. Loupe's provider reads calendars and counts existing events, so
write-only access is not enough for this category.

## Loupe Signals

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `calendarCount` | `EKEventStore().calendars(for: .event).count` | Calendar full access | Active local calendar-store inventory read after permission gate | Include | Medium to high. Calendar count reveals account and subscription complexity, work/personal separation, family calendars, birthdays, and imported calendars. |
| `sourceCount` | Unique `EKCalendar.source.title` values from event calendars | Calendar full access | Active local source/account metadata read after permission gate | Include | High. Distinct provider count reveals service topology and can expose enterprise or school account use. |
| `sources` | Sorted list of unique `EKCalendar.source.title` values | Calendar full access | Active local source/account metadata read after permission gate | Include | High. Provider names such as iCloud, Google, Exchange, or custom source titles can expose services, employers, institutions, or sync history. |
| `types` | Unique mapped `EKCalendar.type` values: `local`, `calDAV`, `exchange`, `subscription`, `birthday`, or `unknown` | Calendar full access | Active local calendar metadata read after permission gate | Include | Medium. Types are coarse, but they strongly constrain the source list and reveal subscription, birthday, Exchange, or local-only use. |
| `events60d` | `predicateForEvents` from 30 days before now to 30 days after now, then `events(matching:)` count | Calendar full access | Active local event query after permission gate | Include | High. Routine density in a rolling 60-day window is user-shaped and can reveal work cadence, travel, school, health, caregiving, or meeting-heavy life patterns. |

## Permission and Collection Class

Loupe's permission path checks `EKEventStore.authorizationStatus(for: .event)`
and, when status is `notDetermined`, calls `requestFullAccessToEvents()`. The
app declares `NSCalendarsFullAccessUsageDescription` with a prompt explaining
that it counts calendars, sources, and events in a 60-day window.

The provider has no stream path and does not subscribe to EventKit change
notifications. The one-shot `collect()` path is still active local collection:
Loupe opens an EventKit store, inventories calendars, reads source titles and
calendar types, builds an event predicate, and asks EventKit for matching
events so it can count them.

This is not a pre-permission passive surface. Calendar full access is a
protected resource grant. The fact that Loupe emits counts rather than event
contents lowers direct exposure in the UI, but the provider still touches
sensitive calendar data after user consent.

The privacy impact is high after grant. Calendar density and source metadata
can expose work routines, religious or family calendars, subscribed calendars,
school or enterprise accounts, and service providers. A 60-day count can be
less sensitive than titles or locations, but it is still behavioral metadata.

## Fingerprinting Value

Calendar source names are the strongest inventory signal. A simple iCloud-only
store is common, but combinations of iCloud, Google, Exchange, CalDAV,
subscriptions, delegated calendars, and custom source titles can be rare.
Provider names can also reveal employers, schools, or account migrations.

Calendar count and type set add structure. Birthday calendars, subscribed
calendars, Exchange calendars, local calendars, and CalDAV calendars each point
to different user behavior and services. The exact tuple can persist for years.

`events60d` is a strong behavioral signal because it reflects current routine
density. A sparse calendar, a meeting-heavy work calendar, school terms,
medical schedules, travel periods, holidays, and family-care patterns can all
change the count. The value moves with time, which makes it useful for both
correlation and activity inference.

The rolling window is also a coherence check. It depends on `Date()`,
`Calendar.current`, timezone behavior, and real EventKit recurrence expansion.
A synthetic profile that spoofs time or locale while leaving the real event
window count visible can leak contradictions.

## Mitigation Strategy Ideas

### `calendar.permission_gate`

Treat Calendar authorization and EventKit store access as one surface:

- `EKEventStore.authorizationStatus(for: .event)`
- `EKEventStore.requestFullAccessToEvents`
- deprecated `requestAccess(to: .event)` paths if target apps still use them
- write-only event access APIs, as a separate compatibility state
- EventKit calendar and event query APIs used after authorization

Do not report full access when the app only has write-only access. Loupe's
signals require reading existing calendars and events. A target app that can
create events but cannot read the store should not receive calendar inventory
or event counts.

Compatibility default should pass through for calendar, scheduling,
productivity, travel, meeting, enterprise, health, family, and automation apps.
Strict privacy behavior can deny full access or use an authorized-empty profile
for apps whose request is not tied to a clear user-facing calendar feature. If
authorized-empty is selected, calendar inventory and event queries must both
return empty native shapes.

### `calendar.inventory`

Hook calendar inventory and source metadata together:

- `EKEventStore.calendars(for: .event)`
- `EKCalendar.source`
- `EKSource.title`
- `EKCalendar.type`
- source and calendar identifier lookups if future coverage observes them

Strict mode can return a small common calendar profile, such as one iCloud-like
source with a small number of ordinary calendars. If a source list is
synthetic, `sourceCount`, `sources`, `types`, and `calendarCount` must all be
derived from the same profile.

Avoid unique synthetic source names. A generated employer-like, school-like, or
seed-derived account name can identify the profile and can be more sensitive
than pass-through.

### `calendar.event_density`

Hook event queries that expose routine density:

- `predicateForEvents(withStart:end:calendars:)`
- `events(matching:)`
- `enumerateEvents(matching:using:)` if target apps use it
- recurrence-expanded event results for the same time window

Default should pass through for apps that show, edit, sync, or reason about real
calendar events. Strict mode can bucket event counts, cap them, or return a
coherent synthetic calendar only when the app does not need functional calendar
data.

Do not only rewrite Loupe's final count. If a target app can inspect returned
`EKEvent` objects, the number of objects, calendars, recurrence behavior, and
event metadata must match the aggregate result.

## Derivation Considerations

Calendar values are an EventKit tuple:

```text
authorization state determines whether calendar reads are available
calendarCount is the number of event calendars in the synthetic store
sourceCount equals the number of unique source titles
sources contains exactly those source titles
types comes from the calendars in the same store
events60d is counted from events attached to those calendars
```

Calendar source and type profiles should come from small common cohorts. Avoid
per-user synthetic source titles, rare account names, or readable Loupehole
implementation strings.

`events60d` should be a low-entropy behavioral bucket unless the mitigation can
return a full coherent event set. It should be stable inside short observation
windows and should change only when time advances, the selected profile
rotates, or a modeled event mutation occurs.

The event window depends on current date, timezone, locale calendar, recurrence
rules, and calendar availability. If Loupehole spoofs system time, timezone,
locale, or calendar identifiers, Calendar signals must not expose the real
timeline through an unmodified rolling event count.

Calendar and Reminders should share account-family coherence where possible.
If a protected profile claims an iCloud-only calendar store but exposes
Exchange-shaped reminder lists elsewhere, the combined personal-data profile is
less believable.

## Impact and Tradeoffs

Calendar spoofing has high functional risk. Apps use EventKit to show meetings,
schedule events, avoid conflicts, create reminders from events, join calls,
display travel plans, and automate user workflows. Synthetic data can break the
app in obvious ways.

Denying full access is a strong privacy protection for probes, but it removes
legitimate calendar features. Write-only access may be a good compromise for
apps that only create events, but it does not support Loupe-style inventory or
event-count reads.

Inventory normalization can hide account topology, but it may confuse apps that
need the correct destination calendar or account source. Event-count
normalization is safer when the app never displays individual events; it is much
riskier for calendar clients.

Partial coverage is easy to detect. Returning generic sources while real events
still contain real calendars, attendees, timezones, or recurrence patterns can
create a fingerprinting contradiction and expose the mitigation.

## Exclusion Note

Omitted from this Loupe signal plan:

- event titles
- event notes
- attendees and organizers
- event locations and URLs
- alarms, recurrence details, attachments, and availability
- individual calendar titles

Reason: the reviewed provider does not emit these values. EventKit full access
can expose them to target apps, so a broader Calendar privacy mode must treat
them as sensitive even though Loupe only reports inventory and counts.

## Relevance

Calendar is a high-privacy, permissioned fingerprint category. It is less
relevant than no-prompt passive surfaces for default v1 stealth mitigations, but
it matters for post-permission app policy because Calendar metadata is dense,
personal, and behaviorally meaningful.

For Loupehole planning, the most relevant surfaces are the full-access
permission gate, calendar/source/type inventory, and rolling event-density
queries. The practical default should be pass-through for real calendar apps,
with denial or coherent low-entropy profiles reserved for apps that request
Calendar access without a clear user-facing need.
