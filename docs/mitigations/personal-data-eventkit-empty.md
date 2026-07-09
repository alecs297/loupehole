# `personal_data.eventkit`

The EventKit personal-data option normalizes Calendar and Reminders reads to denied, empty stores. It covers the assigned Calendar and Reminders surface pages with one shared EventKit adapter so authorization, inventory, and fetch behavior stay coherent.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `personal_data.eventkit` |
| Implemented mitigation | `personal_data.eventkit.inventory.empty` |
| Policy seeds | None |
| User-facing name | Calendar and Reminders inventory |
| Status | Experimental |
| Surface | Calendar, Reminders |
| Classification | Permissioned personal-data inventory; active hook mitigation |
| Affected APIs | `EKEventStore.authorizationStatus(for:)`, `requestAccess(to:completion:)`, `requestFullAccessToEvents`, `requestWriteOnlyAccessToEvents`, `requestFullAccessToReminders`, `calendars(for:)`, `predicateForEvents`, `events(matching:)`, `enumerateEvents(matching:using:)`, `predicateForIncompleteReminders`, `fetchReminders(matching:completion:)` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | Calendar full access and Reminders full access |

## Surface And Relevance

Calendar access exposes account/source topology, calendar types, and event density. Reminders access exposes reminder-list count, user-authored list titles, and incomplete-task count. Both surfaces are EventKit-backed, permissioned, and highly personal after grant.

## Mitigation Strategy

The mitigation hooks `EKEventStore` class and instance methods for `EKEntityTypeEvent` and `EKEntityTypeReminder`. It reports denied authorization, completes access requests with `NO`, returns no event or reminder calendars, returns empty event arrays, suppresses event enumeration callbacks, and completes reminder fetches with an empty array.

It uses one module for both Calendar and Reminders because both APIs share `EKEventStore.authorizationStatusForEntityType:` and `calendarsForEntityType:`. Splitting them into independent modules would make double-hook ordering a source of incoherence.

## Derivation And Lifetime

No policy seeds are declared because the mitigation returns a denied or empty EventKit profile and does not synthesize calendar sources, list names, events, or reminders.

| Item | Value |
| --- | --- |
| Value shape | Denied EventKit authorization, empty event/reminder calendars, empty event and reminder fetches |
| Derivation input | None |
| Storage behavior | None |
| Scope behavior | Runtime policy controls activation; no per-scope EventKit profile is generated |
| Calendar/Reminders coherence | Both entity types are denied and empty through the same adapter |

## Impact And Tradeoffs

This can break calendars, scheduling, travel, meeting, task-management, automation, grocery, and productivity features. It is appropriate only for strict privacy behavior where exposing Calendar or Reminders data to the target app is worse than disabling those features.

The mitigation does not fabricate source names, calendar titles, reminder-list titles, recurrence-expanded events, due-date behavior, or mutation state. EventKit creation and save APIs are left unchanged except that the covered read/authorization paths report no readable store.

## Validation

Expected observations after catalog selection and generation:

- Calendar and Reminders authorization probes report denied.
- Calendar `calendars(for: .event)` and Reminder `calendars(for: .reminder)` return empty arrays.
- Loupe-style `events(matching:)` and `fetchReminders(matching:)` produce zero results.
- Calendar source/type lists and Reminders list-title summaries are empty.

No device validation has been recorded for this mitigation yet.

## Rollback And Pass-Through

Disabling this mitigation restores original EventKit behavior. If `EKEventStore` or all targeted selectors are unavailable, the installer registers a no-op. Unsupported entity types pass through where an original implementation is available.
