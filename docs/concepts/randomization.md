# Randomization

## Definition

**Randomization** is the use of entropy to choose a seed, state blob, cohort value, or bounded offset. It is not a default policy for API responses.

Loupehole distinguishes between randomness that establishes a controlled lifecycle and randomness that creates unstable, implausible, or user-unique observations.

## Acceptable roles for randomness

| Role | Why it can be appropriate |
| --- | --- |
| Package root seed creation | Creates persistent private root material when package state first exists. |
| Per-app-install marker creation | Defines a deliberate rotation boundary for one installation lifecycle. |
| Initial persisted state generation | Produces a stable state blob that later reads reuse. |
| Bounded offset inside a documented temporal or cohort model | Adds variation while preserving an explicit distribution and invariant. |
| Build variability input | Reduces unnecessary static sameness without changing observable semantics. |

## Unsafe roles for randomness

| Pattern | Why it is unsafe |
| --- | --- |
| New value on every API call | Breaks lifetime expectations and is trivially detectable. |
| Independent random answers for related APIs | Creates contradictions across app-visible surfaces. |
| Arbitrary random user-agent, hardware, locale, or timestamp fields | Produces rare combinations without a coherent profile. |
| Random fallback after state/policy failure | Hides a defect while creating a second, undocumented identity. |
| User-exposed unlimited custom values | Produces configuration entropy and makes users more unique. |

## Coherent randomness

The temporal mitigation group shows the intended pattern. A state domain chooses a boot anchor and volume-before-boot offset once, keeps them stable for the selected scope, and enforces an ordering. The hook adapters do not independently choose dates.

```text
profile epoch ≤ volume creation time < boot time < current time
```

The important property is not that the values are “random.” It is that they are generated once within a constrained model, retained for the right lifetime, and reused consistently by every covered API.

## Relationship to seeds and profiles

A seed determines reproducible derived bytes. A profile defines the plausible common shape or distribution. Randomness can choose a state or a bounded point within that profile; it does not replace the profile. A different seed should produce a different coherent instance, not a different set of rules.

## Review questions

For every use of entropy, documentation should answer:

- What is random?
- When is it generated?
- Where is it stored, if at all?
- Who observes it?
- How long does it persist?
- Which values must agree with it?
- What rotation event changes it?
- What happens if persistence fails?
