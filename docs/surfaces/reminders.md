# Reminders

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/RemindersProvider.swift`

Loupe category: Reminders
Loupe tier: permissioned local EventKit reminders inventory and incomplete-item
count, with active one-shot reminder-store reads after user grant
Permission required: Reminders full access through `EKEventStore`; Loupe
declares `NSRemindersFullAccessUsageDescription` and requests full reminders
access before collection.
Primary relevance: reminder-list names, task-store size, service/account
coherence, routine and obligation leakage, and post-permission privacy impact.

This category covers metadata Loupe derives from EventKit reminder lists and
incomplete reminders. Loupe does not display individual reminder titles, notes,
or URLs, but it does display reminder list titles and queries all incomplete
reminders in the selected lists to compute a count.

## Official Links

- [`EventKit`](https://developer.apple.com/documentation/eventkit)
- [`EKEventStore`](https://developer.apple.com/documentation/eventkit/ekeventstore)
- [`EKEventStore.authorizationStatus(for:)`](https://developer.apple.com/documentation/eventkit/ekeventstore/authorizationstatus%28for%3A%29)
- [`EKEventStore.requestFullAccessToReminders(completion:)`](https://developer.apple.com/documentation/eventkit/ekeventstore/requestfullaccesstoreminders%28completion%3A%29)
- [`NSRemindersFullAccessUsageDescription`](https://developer.apple.com/documentation/bundleresources/information-property-list/nsremindersfullaccessusagedescription)
- [`EKEventStore.calendars(for:)`](https://developer.apple.com/documentation/eventkit/ekeventstore/calendars%28for%3A%29)
- [`EKCalendar`](https://developer.apple.com/documentation/eventkit/ekcalendar)
- [`EKCalendar.title`](https://developer.apple.com/documentation/eventkit/ekcalendar/title)
- [`EKEntityType.reminder`](https://developer.apple.com/documentation/eventkit/ekentitytype/reminder)
- [`EKEventStore.predicateForIncompleteReminders(withDueDateStarting:ending:calendars:)`](https://developer.apple.com/documentation/eventkit/ekeventstore/predicateforincompletereminders%28withduedatestarting%3Aending%3Acalendars%3A%29)
- [`EKEventStore.fetchReminders(matching:completion:)`](https://developer.apple.com/documentation/eventkit/ekeventstore/fetchreminders%28matching%3Acompletion%3A%29)

Apple treats reminders as protected EventKit data. Loupe's provider requires
full reminder access because it reads existing reminder lists and incomplete
reminder records.

## Loupe Signals and Decisions

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `listCount` | `EKEventStore().calendars(for: .reminder).count` | Reminders full access | Active local reminders inventory read after permission gate | Include | Medium to high. List count reveals task organization style, account/source complexity, and whether the user relies heavily on Reminders. |
| `listTitles` | Joined `EKCalendar.title` values from reminder calendars | Reminders full access | Active local reminder-list metadata read after permission gate | Include | High. List names can expose projects, family members, workplaces, locations, health topics, chores, travel, or other directly personal categories. |
| `incomplete` | `predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: lists)` then `fetchReminders` count | Reminders full access | Active local reminder query after permission gate | Include | High. The open-task count is user-shaped, changes with behavior, and can reveal workload, routine, neglect, or task-management style. |

## Permission and Activity Classification

Loupe's permission path checks `EKEventStore.authorizationStatus(for:
.reminder)` and, when status is `notDetermined`, calls
`requestFullAccessToReminders()`. The app declares
`NSRemindersFullAccessUsageDescription` with a prompt explaining that it counts
reminder lists, shows list titles, and counts incomplete reminders.

The provider has no stream path and does not subscribe to EventKit change
notifications. The one-shot `collect()` path is still active local collection:
Loupe opens an EventKit store, inventories reminder calendars, reads their
titles, builds a predicate for all incomplete reminders across those lists, and
fetches reminder objects so it can count them.

This is not a pre-permission passive surface. Reminders full access is a
protected resource grant. After the grant, the privacy impact is high because
list titles and incomplete-task counts expose personal obligations and
organization habits.

Loupe does not emit individual reminder titles, notes, URLs, priorities, due
dates, recurrence rules, alarms, or completion timestamps. Those values are
excluded from this page's Loupe signal set, but target apps with full Reminders
access may still fetch them directly.

## Fingerprinting Value

`listTitles` is the most sensitive signal. Unlike generic counts, list names are
human-authored labels. They can include project names, children's names,
medical topics, shopping locations, employer names, travel plans, household
roles, or private personal systems.

`listCount` is a moderate-to-high value cohort signal. A user with one default
list differs from a user with many project, shared, work, grocery, location, or
smart-list style groups. The count also constrains the list-title output.

`incomplete` is a behavioral signal. It can be stable enough to correlate
sessions but dynamic enough to reveal task activity. A zero count, a small
personal count, or hundreds of open reminders each describes a different usage
pattern.

The query has no due-date bounds, so it counts all incomplete reminders visible
through the selected lists. That makes the value broader than a short rolling
window and potentially more identifying than the Calendar `events60d` count.

## Mitigation Strategy Ideas

### `reminders.permission_gate`

Treat Reminders authorization and EventKit store access as one surface:

- `EKEventStore.authorizationStatus(for: .reminder)`
- `EKEventStore.requestFullAccessToReminders`
- deprecated `requestAccess(to: .reminder)` paths if target apps still use them
- reminder calendar inventory and reminder fetch APIs used after authorization

Compatibility default should pass through for task managers, productivity apps,
automation tools, calendar/reminder clients, grocery apps, and apps where the
user intentionally works with reminders. Strict privacy behavior can deny full
access to apps that request Reminders only as a fingerprinting probe.

Do not report authorized status while returning an empty or failing reminder
store unless that empty store is the chosen coherent profile. Authorization
state, list inventory, and fetch results must agree.

### `reminders.list_inventory`

Hook reminder-list inventory and titles together:

- `EKEventStore.calendars(for: .reminder)`
- `EKCalendar.title`
- `EKCalendar.source` and identifiers if future coverage observes them
- list lookup APIs that expose the same reminder calendars

Strict mode can replace personal list titles with a small common set such as
`Reminders`, `Shopping`, and `Work`, but only when the returned reminder objects
also belong to those lists. For apps that display or edit reminders, pass
through is usually safer.

Never generate seed-derived personal-looking list titles. A unique synthetic
project name, family name, or profile-specific phrase can become a direct
identifier.

### `reminders.incomplete_count`

Hook incomplete-reminder queries:

- `predicateForIncompleteReminders(withDueDateStarting:ending:calendars:)`
- `fetchReminders(matching:completion:)`
- any future async wrappers or filtered fetch helpers

Strict mode can bucket the count, cap high values, or return a coherent
synthetic reminder store. A count-only rewrite is not enough if the target app
can inspect the returned `EKReminder` array.

If the target app creates, completes, or deletes reminders, the synthetic count
must move in the expected direction or pass through. A frozen count after a
visible user action is both user-visible and detectable.

## Derivation and Coherence Considerations

Reminders values are a coherent task-store tuple:

```text
authorization state determines whether reminder reads are available
listCount equals the number of returned reminder calendars
listTitles contains exactly those returned list titles
incomplete count is derived from reminders attached to those lists
created/completed/deleted reminders update future counts consistently
```

List titles should be common cohort labels or pass-through values. They should
not contain readable Loupehole strings, mitigation names, salts, seed material,
or rare synthetic personal labels.

`incomplete` should be bucketed or modeled as a slowly changing state value,
not an exact seed-derived number. It should remain stable across immediate
re-reads and change only through time, selected profile changes, or observed
reminder mutations.

Calendar and Reminders should share EventKit account coherence where possible.
If a synthetic profile exposes work-heavy Exchange calendars, reminder lists can
plausibly include work lists. If the Calendar profile is iCloud-only and
minimal, a large enterprise-shaped reminders inventory may be contradictory.

If system time, timezone, or locale are spoofed, reminder due-date queries,
recurrence behavior, and date-bounded incomplete counts in target apps need to
remain coherent even though Loupe's current query uses no due-date bounds.

## Impact and Tradeoffs

Reminders spoofing has high user-impact risk. Apps may show reminder lists,
create tasks, complete tasks, sync with calendar workflows, trigger automation,
or rely on Reminders as a real task database. Synthetic results can make the
app visibly wrong and may cause missed tasks or duplicate work.

Denying permission is strong protection for probes, but it removes legitimate
task features. Pass-through is the safest default when the user has knowingly
granted Reminders access to an app whose purpose depends on that data.

List-title normalization protects directly personal labels, but it is also
visible. A user who expects a list named after a project or family member will
notice generic replacements. Use strict normalization only when the target app
does not need to display real lists.

Incomplete-count bucketing can reduce entropy for simple probes, but it does
not protect reminder contents if the app can fetch the returned objects.
Complete coverage must include list inventory, reminder fetches, mutations, and
authorization state.

## Exclusion Note

Omitted from this Loupe signal plan:

- individual reminder titles
- notes
- URLs
- priorities
- due dates
- recurrence rules
- alarms
- completion dates and timestamps
- list source names, except as future coherence context

Reason: the reviewed provider does not emit those values. They remain sensitive
Reminders data and must be considered if Loupehole later designs a broader
EventKit reminders privacy mode.

## Relevance

Reminders is a high-privacy, permissioned fingerprint category. It is not a
silent no-prompt passive surface, but after grant it can expose personal labels
and task behavior with high semantic value.

For Loupehole planning, the most relevant surfaces are the full-access
permission gate, reminder-list titles, and incomplete-reminder counts. Default
behavior should be conservative and compatibility-first, with denial or
coherent low-entropy task-store profiles reserved for apps that request
Reminders access without a clear user-facing need.
