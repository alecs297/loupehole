# `system.memory_counters`

The memory counters option reduces precision in covered passive memory-state reads. It applies bounded seed-derived noise to Mach system VM statistics and process-available-memory reads, and coherent rounding to covered current-process `task_info` byte counters.

## Metadata

| Field | Value |
| --- | --- |
| Option ID | `system.memory_counters` |
| Implemented mitigation | `system.memory_counters.mach.bucketed` |
| Policy seeds | `system_memory_counter_noise`, `process_memory_counter_precision` |
| User-facing name | Memory counters |
| Status | Experimental |
| Surface | System info |
| Classification | Passive live memory-state read; active C hook mitigation |
| Affected APIs | `host_statistics`, `host_statistics64`, `os_proc_available_memory`, imported `task_info` |
| Default behavior | Enabled when selected and runtime policy allows the module |
| Permission requirement | None |

## References

- Apple Mach: `host_statistics64`.
- Apple Mach: `vm_statistics64_data_t`.
- Apple OS: `os_proc_available_memory`.
- [Apple XNU task-info ABI](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/mach/task_info.h): basic task sizes, VM revisions, and field types.
- [Apple XNU task-info implementation](https://github.com/apple-oss-distributions/xnu/blob/main/osfmk/kern/task.c): VM revision negotiation and available-memory semantics.

## Surface And Relevance

Mach VM statistics expose free, active, inactive, wired, compressed, page-in, page-out, and fault counters. These values are live state rather than fixed hardware identity, but exact tuples can link launches and reveal memory pressure, workload, and recent device activity.

Current-process memory reads expose virtual size, resident usage, footprint, and peaks. SDKs can retain the initial, current, and highest allocation observations. These are the app's own live accounting values, so precision reduction has a narrower privacy boundary than shaping shared system state.

The supplied binary analysis labels flavor `0x14` as `TASK_VM_INFO`. Darwin defines `0x14` as `MACH_TASK_BASIC_INFO` and `0x16` as `TASK_VM_INFO`. Both are covered, but resident size and physical footprint are different metrics and are not forced to agree.

## Mitigation Strategy

The system-counter hooks for `host_statistics`, `host_statistics64`, and `os_proc_available_memory` preserve original return codes and struct sizes, then subtract bounded seed-derived and live-state-dependent noise from page counts, lifetime counters, and available process memory. The `host_statistics64` shaper only writes fields that fit in the returned count.

Shared VM fields use the same derivation context across legacy and 64-bit statistics. Equal original inputs therefore produce equal shaped values; separate live samples and legacy-width saturation can still differ. The module does not force independent kernel snapshots to agree or reconstruct an exact page-accounting sum.

The process extension rebinds imported `task_info` symbols. It calls the original first and only shapes successful reads whose task port equals `mach_task_self()`. Direct function addresses, direct Mach messages, alternate port names for the current task, and other tasks are outside this imported-symbol boundary.

| Flavor | Shaped values |
| --- | --- |
| `MACH_TASK_BASIC_INFO` | Virtual size, resident size, maximum resident size |
| `TASK_BASIC_INFO_32`, SDK-defined `TASK_BASIC_INFO_64` | Virtual and resident sizes; the SDK handles the iOS legacy 64-bit flavor alias |
| `TASK_VM_INFO`, `TASK_VM_INFO_PURGEABLE` | Virtual/resident sizes and resident peak; device, internal, external, reusable, purgeable, and compressed byte sizes and associated peaks/lifetime; physical footprint; positive byte ledgers present in the SDK and returned revision |

One quantum, derived from the active seed and scope, rounds all covered process usage sizes downward. The quantum is 64-256 KiB in 16 KiB steps, and each reduction is strictly less than the quantum. Zero remains zero, and small positive values can round to zero. The same monotone function preserves equal source values across flavors, valid current/peak and subset ordering, and nondecreasing peaks when the original peak grows. Negative signed ledger values pass through. Component sums can differ from rounded totals by the rounding error; the mitigation does not reconstruct an exact synthetic memory ledger.

When present, `TASK_VM_INFO.limit_bytes_remaining` uses the same `system_memory_counter_noise` context and bounds as `os_proc_available_memory`. Equal original available-memory values therefore yield equal shaped values. These reads remain live samples and need not agree when the underlying system state changes between calls.

Every process field must fit entirely within both the original caller capacity and the returned count, measured in Mach integer units. Counts, revision negotiation, CPU/task times, region counts, page size, address bounds, and event counters such as decompressions and swapins remain unchanged. Unknown flavors and revision tails pass through.

The mitigation never reports more bytes than the covered original read, does not alter allocations, and does not change process memory limits. `NSProcessInfo.physicalMemory`, hardware-memory sysctls, and other hardware RAM constants remain deferred.

## Derivation And Lifetime

| Item | Value |
| --- | --- |
| Policy seed identifiers | `system_memory_counter_noise`, `process_memory_counter_precision` |
| Generated seed symbols | `LHGeneratedPolicySeed_system_memory_counter_noise`, `LHGeneratedPolicySeed_process_memory_counter_precision` |
| System value shape | Mach VM page counts, lifetime counters, and available-memory byte counts |
| System derivation input | active/practical seed + generated policy seed + active `LHScope` + field context; original value contributes live-state noise |
| Process value shape | One shared 64-256 KiB rounding quantum for supported nonnegative usage byte counters |
| Process derivation input | active/practical seed + generated policy seed + active `LHScope`; original value is rounded, not independently randomized |
| Helper ownership | `MemoryCountersMitigation.c` owns shaping and coherence; `LHMitigationValues.h` supplies scoped bounded derivation |
| Storage behavior | No persisted mitigation-owned state; the module retains its runtime policy and original function pointers |
| Lifetime | System values follow real state; the process quantum is stable for the same active seed and scope, while reported sizes follow real usage |
| Dependencies | Mach SDK layouts, generated source policy seeds, active runtime seed/scope, and the imported-symbol hook backend; no other mitigation's values or shared state |

Both streams are declared with `LH_POLICY_SEED` in mitigation source. `system_memory_counter_noise` selects stable per-field noise domains; `process_memory_counter_precision` selects a shared process quantum. The ordinary generator must run after adding the declaration so production builds receive its seed bytes.

## Impact And Tradeoffs

Apps that diagnose memory pressure, tune caches, or show exact VM statistics lose precision. Because values remain lower than the original where applicable, the module avoids optimistic fake memory claims that could lead to over-allocation.

Process usage can be understated by less than 256 KiB per shaped field, and small categories can disappear into a zero bucket. Apps using exact process sizes to tune caches or display accounting can observe rounding artifacts and small discrepancies in component sums. The scoped quantum is observable and the values still track substantial allocation changes; this is precision reduction, not workload hiding or universal memory API coverage.

## Validation

Expected observations:

- VM page-count fields are perturbed below the original values without fixed bucket multiples.
- lifetime counters such as pageins, pageouts, faults, compressions, and decompressions are perturbed below the original values without fixed bucket multiples.
- `os_proc_available_memory` is perturbed below the original value without a fixed byte bucket.
- Covered successful current-task `task_info` reads round usage bytes with one shared quantum and preserve valid current/peak ordering.
- Equal virtual/resident inputs agree across covered basic and VM flavors; physical footprint keeps its separate meaning.
- VM revisions only change completely returned fields, with no writes past the original capacity or returned revision.
- Equal `limit_bytes_remaining` and `os_proc_available_memory` inputs produce equal available-memory outputs.
- Task CPU times, page sizes, address bounds, errors, unsupported flavors, other-task reads, and negative signed ledgers retain their original behavior.

Run the focused host check without generating or building the runtime:

```sh
sh src/scripts/verify/process-memory-check.sh
```

The harness compiles the actual mitigation with native Darwin Mach headers, real seed derivation helpers, and test-only registry/seed fixtures. Address and undefined-behavior sanitizers check every integer boundary through the current VM layout, basic layouts, truncated revisions, oversized returned counts, untouched tails, coherence, derivation failure, and import-only installation. It requires a Darwin host compiler/SDK and does not establish iOS injection coverage.

Device validation remains required: compare repeated covered reads in an injected app, test the SDK collector's actual flavor and fields, exercise supported OS revisions, and verify cache/diagnostic behavior. Hardware RAM queries and unrelated memory APIs remain uncovered. Full integration uses the normal generator, standalone audit, and package checks.

## Rollback And Pass-Through

Disabling the module restores original memory counters. Original failures and unsupported flavors pass through. Process reads also pass through for other task ports, missing buffers/counts, or unavailable process derivation. Missing fields and unrecognized revision tails are never written. If no target symbol can be hooked, the module registers as a no-op; partial hook installation only covers the hooks installed successfully.
