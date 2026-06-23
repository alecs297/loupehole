# Contacts

Source reviewed: `.research/upstream/loupe/code/Loupe/Providers/ContactsProvider.swift`

Loupe category: Contacts
Loupe tier: permissioned local personal-store inventory, with active one-shot
contact-store enumeration after user grant
Permission required: Contacts access through `CNContactStore`; Loupe declares
`NSContactsUsageDescription` and requests Contacts permission before collection.
Primary relevance: social graph size, address-book source count, contact-field
shape, custom phone labels, and post-permission privacy impact.

This category covers metadata Loupe derives from the user's Contacts database.
Loupe does not display contact names, phone numbers, email addresses, or postal
addresses, but it still requests access to sensitive personal data and walks
the contact store to compute counts and label summaries.

## Official Links

- [`CNContactStore`](https://developer.apple.com/documentation/contacts/cncontactstore)
- [`CNContactStore.authorizationStatus(for:)`](https://developer.apple.com/documentation/Contacts/CNContactStore/authorizationStatus%28for%3A%29)
- [`CNContactStore.requestAccess(for:completionHandler:)`](https://developer.apple.com/documentation/contacts/cncontactstore/requestaccess%28for%3Acompletionhandler%3A%29)
- [`NSContactsUsageDescription`](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSContactsUsageDescription)
- [`CNContactFetchRequest`](https://developer.apple.com/documentation/contacts/cncontactfetchrequest)
- [`CNContactFetchRequest.keysToFetch`](https://developer.apple.com/documentation/contacts/cncontactfetchrequest/keystofetch)
- [`CNContactStore.containers(matching:)`](https://developer.apple.com/documentation/contacts/cncontactstore/containers%28matching%3A%29)
- [`CNContactStore.enumerateContacts(with:usingBlock:)`](https://developer.apple.com/documentation/contacts/cncontactstore/enumeratecontacts%28with%3Ausingblock%3A%29)
- [`CNContact.phoneNumbers`](https://developer.apple.com/documentation/contacts/cncontact/phonenumbers)
- [`CNContact.emailAddresses`](https://developer.apple.com/documentation/contacts/cncontact/emailaddresses)
- [`CNContact.postalAddresses`](https://developer.apple.com/documentation/contacts/cncontact/postaladdresses)
- [`CNLabeledValue.localizedString(forLabel:)`](https://developer.apple.com/documentation/contacts/cnlabeledvalue/localizedstring%28forlabel%3A%29)

Apple treats Contacts as a protected resource. Loupe's category is therefore a
permissioned demonstration surface, not a silent passive fingerprint available
before user consent.

## Loupe Signals and Decisions

| Loupe signal | Provider source | Permission | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- | --- |
| `containerCount` | `CNContactStore().containers(matching: nil).count` | Contacts | Active local contact-store metadata read after permission gate | Include | Medium. The number of sources such as iCloud, local, Exchange, or other synced accounts reveals address-book topology and must match later contact fetch behavior. |
| `total` | `CNContactStore.enumerateContacts(with:)` using a `CNContactFetchRequest` | Contacts | Active local contact-store enumeration after permission gate | Include | High. Total contact count is a durable social-graph size signal that can link users after they grant access. |
| `phoneCount` | Sum of `contact.phoneNumbers.count` over enumerated contacts | Contacts | Active local contact field enumeration after permission gate | Include | High. Phone-number density reveals communication habits and address-book shape even without exposing the actual numbers. |
| `emailCount` | Sum of `contact.emailAddresses.count` over enumerated contacts | Contacts | Active local contact field enumeration after permission gate | Include | Medium to high. Email density and ratio against phone count can distinguish personal, work, CRM-like, or migrated address books. |
| `postalCount` | Sum of `contact.postalAddresses.count` over enumerated contacts | Contacts | Active local contact field enumeration after permission gate | Include | Medium. Postal-address counts are lower frequency and can expose older, professional, family, or location-heavy address books. |
| `phoneLabels` | Top six localized phone labels from each `CNLabeledValue.label`, with unlabeled values grouped | Contacts | Active local contact label enumeration after permission gate | Include | High. Standard label mix is useful, and custom labels can directly encode relationships, roles, or personal vocabulary. |

## Permission and Activity Classification

Loupe's permission path checks `CNContactStore.authorizationStatus(for:
.contacts)` and, when status is `notDetermined`, calls
`CNContactStore().requestAccess(for: .contacts)`. The app declares
`NSContactsUsageDescription` with a prompt that says it counts contacts and
field labels without displaying raw names, numbers, email addresses, or postal
addresses.

The provider has no stream path and does not observe future contact changes.
The one-shot `collect()` path is still active local collection: Loupe opens the
Contacts database, requests containers, and enumerates contacts with phone,
email, and postal-address keys to compute aggregate signals.

This is not a pre-permission passive surface. A normal app should not be able to
read these values silently before Contacts access is granted. After access is
granted, however, the privacy impact is high because counts and labels are
derived from the user's address book, which is a sensitive relationship graph.

Loupe does not emit raw contact names, phone numbers, email addresses, or postal
addresses. Those fields are excluded from this fingerprint page's signal set,
but any real Contacts mitigation must still treat them as protected personal
data because target apps can fetch them directly after authorization.

## Fingerprinting Value

Contact count is a strong post-permission identifier. It changes slowly, is
shaped by years of user behavior, and can correlate across app installs or
across apps that receive the same Contacts grant.

Field counts add social-graph texture. A phone-heavy address book, an
email-heavy professional book, a sparse migrated book, or an address book with
many postal addresses can distinguish cohorts even when raw values are hidden.
Ratios such as `phoneCount / total`, `emailCount / total`, and
`postalCount / total` are often more informative than any single count.

Container count reveals account topology. iCloud-only, local-only, Exchange,
Google, CardDAV, and multi-source contact stores can map to work, school,
enterprise, or migration history. It also constrains what a synthetic contact
inventory can plausibly return.

Phone labels are especially sensitive. Common labels such as mobile, home, and
work are lower entropy, but custom labels can expose relationships, languages,
nicknames, or roles. Even a top-six summary can leak uncommon personal
vocabulary.

## Mitigation Strategy Ideas

### `contacts.permission_gate`

Treat Contacts authorization and store access as one surface:

- `CNContactStore.authorizationStatus(for:)`
- `CNContactStore.requestAccess(for:completionHandler:)`
- equivalent async request-access wrappers
- Contacts UI and picker flows if future coverage includes them
- all Contacts store fetch/enumeration APIs used after authorization

Do not synthesize granted Contacts access for an app that the system has denied.
Strict privacy behavior can prefer denial for apps that only ask for Contacts
as a fingerprinting probe. Compatibility behavior should pass through for
messaging, calling, email, contacts, CRM, invite, sync, accessibility, and
enterprise apps that genuinely operate on contacts.

If the policy reports denied or restricted, store reads must match that state.
Returning authorized status while enumeration fails, or denying status while
still returning contact metadata, is easy to detect.

### `contacts.inventory_counts`

Hook the count-producing fetch paths together:

- `CNContactStore.containers(matching:)`
- `CNContactStore.enumerateContacts(with:usingBlock:)`
- direct fetch APIs such as unified contact fetches if future coverage observes
  them
- `CNContactFetchRequest.keysToFetch` behavior when target apps request the
  same phone, email, and postal-address keys

Default should pass through after user grant. Strict mode can bucket counts or
return a small coherent synthetic inventory only for apps that do not need real
Contacts functionality. Useful reductions are broad buckets rather than exact
seed-derived counts.

Avoid fabricating a detailed address book unless the mitigation can make every
Contacts API agree. A count-only hook that says there are 80 contacts while a
later enumeration returns 0 contacts creates a stronger synthetic marker than
pass-through.

### `contacts.phone_labels`

Phone labels should be normalized only as part of the contact inventory. A safe
strict profile can remove custom labels or map them into common labels such as
mobile, home, work, main, and other. Compatibility mode should pass through
because labels are user-visible in contact pickers and communication flows.

Do not generate seed-derived custom labels. Unique labels or uncommon
relationship strings can identify the protected profile and may leak more than
the original top-six summary.

## Derivation and Coherence Considerations

Contacts values are a coherent address-book tuple:

```text
authorization state determines whether store metadata is available
container count constrains source/account topology
total contacts constrains field-count ratios
phone label counts must not exceed phoneCount
phone, email, and postal counts must be plausible for total contacts
enumeration results must agree with aggregate counts
```

Synthetic counts should be low entropy, stable for the selected scope, and
changed only on plausible user or store events. A deterministic exact total
derived directly from the seed can become a new identifier.

Container count should come from a small common source profile. If a profile
claims multiple account sources, the returned contacts and labels should look
like a multi-source address book. If it claims a local-only store, it should not
also expose Exchange- or CardDAV-shaped behavior through adjacent APIs.

Phone, email, and postal counts should be generated as ratios attached to the
selected inventory profile. The values can be bucketed or capped, but they
should not rotate independently between reads.

Custom labels should usually be dropped, bucketed, or passed through. They
should not include readable Loupehole strings, profile names, salts, seed
material, or rare synthetic relationship labels.

## Impact and Tradeoffs

Contacts spoofing has high functional risk. Apps use Contacts access to help
users call, message, email, invite, share, deduplicate, sync, and identify
people. Returning synthetic or empty contacts can break core workflows and make
the app visibly wrong.

Denying permission is the clearest privacy protection for fingerprint-only
apps, but it also prevents legitimate features. Pass-through is safest once the
user deliberately grants Contacts access to an app whose purpose depends on the
address book.

Count bucketing reduces entropy while preserving some coarse behavior, but it
does not protect raw contact values if the app can still fetch them. A serious
Contacts mitigation must cover authorization, enumeration, direct fetches,
labels, and any UI paths that expose the real store.

Partial spoofing is dangerous. Hiding custom phone labels while returning real
phone numbers, or changing aggregate counts while direct enumeration remains
real, gives a tracker an inconsistency signal and can degrade user trust.

## Exclusion Note

Omitted from this Loupe signal plan:

- contact names
- phone number strings
- email address strings
- postal address contents
- birthday, organization, URL, note, image, relationship, and other contact
  fields not requested by Loupe's provider

Reason: the reviewed provider does not emit those values. They remain sensitive
Contacts data and must be considered if Loupehole later designs a broader
Contacts privacy mode.

## Relevance

Contacts is a high-privacy, permissioned fingerprint category. It is not a
silent P0 passive native surface because the user must grant Contacts access,
but it becomes highly identifying after grant and should be documented for
post-permission tracking and app-risk policy.

For Loupehole planning, the most relevant pieces are the permission gate,
aggregate inventory counts, and phone-label normalization. Default behavior
should be conservative: preserve real Contacts behavior for apps with a
legitimate need, and use denial or coarse coherent reductions for apps that ask
for Contacts only to enrich a fingerprint.
