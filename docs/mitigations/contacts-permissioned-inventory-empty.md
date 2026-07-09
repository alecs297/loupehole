# `contacts.permissioned_inventory`

The Contacts permissioned-inventory option normalizes Contacts access to an authorized, empty store with one generic container. It covers Loupe's post-permission address-book metadata probes without fabricating a synthetic contact graph.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `contacts.permissioned_inventory` |
| Implemented mitigation | `contacts.permissioned.inventory.empty` |
| Policy seeds | None |
| User-facing name | Contacts inventory |
| Status | Experimental |
| Surface | Contacts |
| Classification | Permissioned personal-data inventory; active hook mitigation |
| Affected APIs | `CNContactStore.authorizationStatus(for:)`, `CNContactStore.requestAccess(for:completionHandler:)`, `containers(matching:)`, `enumerateContacts(with:usingBlock:)`, `unifiedContacts(matching:keysToFetch:)`, `unifiedContact(withIdentifier:keysToFetch:)`, `CNContainer.identifier`, `name`, `type` |
| Default behavior | Enabled when the mitigation is selected and runtime policy allows the module |
| Permission requirement | Contacts |

## Surface And Relevance

Contacts access exposes address-book topology, contact count, phone/email/postal field density, and custom labels after the user grants access. Loupe counts these values rather than showing raw names or numbers, but the counts still describe the user's social graph.

## Mitigation Strategy

The mitigation hooks `CNContactStore` authorization and read paths. Contacts authorization is reported as authorized, request-access completions receive `YES`, container fetches return one generic container, enumeration succeeds without invoking the contact block, and direct unified-contact fetches return empty results or `nil`.

Container getters are normalized to `identifier = "default"`, `name = "Contacts"`, and local type. The implementation reuses one native container when available and otherwise attempts a bare `CNContainer` instance; if neither can be obtained safely, the container read falls back to an empty array rather than throwing.

It does not synthesize contacts, labels, phone numbers, emails, or postal addresses. That avoids creating a fake graph that adjacent Contacts APIs could contradict. Non-Contacts entity types pass through when an original implementation is available.

## Derivation And Lifetime

No policy seeds are declared because the mitigation owns no synthetic contact graph and persists no state. The observable profile is an authorized but empty Contacts store for the active process while the module is enabled.

| Item | Value |
| --- | --- |
| Value shape | Authorized Contacts access, one generic container when possible, zero enumerated contacts |
| Derivation input | None |
| Storage behavior | None |
| Scope behavior | Runtime policy controls whether the module is active for the scoped app; no per-scope value is generated |
| Rotation behavior | Disabling the module or runtime policy restores pass-through behavior |

## Impact And Tradeoffs

This is a strict privacy mitigation. It can break calling, messaging, email, invite, CRM, sync, and contact-picker workflows that need the real address book. It is safer for apps that request Contacts only to enrich a fingerprint.

The module intentionally does not normalize every Contacts UI surface or mutation API. Apps that present system contact pickers, create contacts, or use unhooked Contacts APIs may still observe real behavior or a mismatch until those paths receive dedicated coverage.

## Validation

Expected observations after catalog selection and generation:

- Contacts authorization probes report authorized.
- Loupe-style container count is one when a native or fallback container can be created.
- Contact enumeration returns zero personal-data inventory.
- Phone, email, postal, and label aggregate counts derived from enumeration are zero.
- If a hook cannot install, the module registers as a no-op.

No device validation has been recorded for this mitigation yet.

## Rollback And Pass-Through

Disabling this mitigation restores the original Contacts behavior. If the `CNContactStore` class or all targeted selectors are unavailable, the installer registers a no-op. The replacement paths do not create fallback contacts when a read cannot be satisfied.
