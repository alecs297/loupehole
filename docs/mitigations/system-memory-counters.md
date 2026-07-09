# `system.memory_counters`

The memory counters option applies bounded seed-derived noise to Mach VM statistics and process-available-memory reads so apps cannot observe exact live memory pressure counters or obvious hard bucket edges.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `system.memory_counters` |
| Implemented mitigation | `system.memory_counters.mach.bucketed` |
| Policy seeds | `system_memory_counter_noise` |
| User-facing name | Memory counters |
| Status | Experimental |
| Surface | System info |
| Classification | Passive live memory-state read; active C hook mitigation |
| Affected APIs | `host_statistics`, `host_statistics64`, `os_proc_available_memory` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None |

## References

- Apple Mach: `host_statistics64`.
- Apple Mach: `vm_statistics64_data_t`.
- Apple OS: `os_proc_available_memory`.

## Surface And Relevance

Mach VM statistics expose free, active, inactive, wired, compressed, page-in, page-out, and fault counters. These values are live state rather than fixed hardware identity, but exact tuples can link launches and reveal memory pressure, workload, and recent device activity.

## Mitigation Strategy

The mitigation hooks `host_statistics`, `host_statistics64`, and `os_proc_available_memory`. It preserves original return codes and struct sizes, then subtracts bounded seed-derived and live-state-dependent noise from page counts, lifetime counters, and available process memory. The `host_statistics64` shaper only writes fields that fit in the caller-provided count, so older/revision-limited buffers are not overrun.

It does not claim more memory than the system reported, does not alter allocations, and does not change process memory limits.

## Derivation And Lifetime

`LH_POLICY_SEED(system_memory_counter_noise)` selects stable per-field noise domains. Values follow the real memory state with small deterministic perturbation and require no state storage.

## Impact And Tradeoffs

Apps that diagnose memory pressure, tune caches, or show exact VM statistics lose precision. Because values remain lower than the original where applicable, the module avoids optimistic fake memory claims that could lead to over-allocation.

## Validation

Expected observations:

- VM page-count fields are perturbed below the original values without fixed bucket multiples.
- lifetime counters such as pageins, pageouts, faults, compressions, and decompressions are perturbed below the original values without fixed bucket multiples.
- `os_proc_available_memory` is perturbed below the original value without a fixed byte bucket.

Device validation is required for task-level memory APIs and sysctl hardware-memory paths, which are not covered by this module.

## Rollback And Pass-Through

Disabling the module restores original memory counters. Original failures and unsupported flavors pass through. If no target symbol can be hooked, the module registers as a no-op.
