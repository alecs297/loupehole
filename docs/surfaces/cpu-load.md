# CPU Load Counters

Source reviewed: supplied device-information binary analysis, section 4
(`getAllProcessorsCpuUsage:` at `0x10013afd4` and
`getCpuUsageForTaskSelf` around `0x10013aed4`). Comparison source:
`.research/upstream/loupe/code/Loupe/Providers/SystemInfoProvider.swift`.
The binary and its disassembly were not independently examined for this page.

Loupe category: System Info (adjacent binary-analysis research)
Loupe tier: passive local system/runtime state
Permission required: none for a TCC prompt; Mach port rights and OS restrictions
still apply
Primary relevance: time-varying shared workload and cross-session correlation
Status: research only; CPU-load implementation explicitly deferred

This page includes cumulative per-processor and aggregate CPU accounting, plus
task/thread APIs that can cross-check workload. The reviewed Loupe provider
collects processor count, not CPU-load counters. These additional signals come
from the supplied analysis or adjacent Apple interfaces, not a new Loupe
provider. Hardware constants and the app's active timed frequency benchmark are
excluded from CPU-load mitigation ownership. Processor topology and the
app-visible boot timeline remain coherence constraints.

No CPU-load mitigation, catalog option, source policy seed, or device validation
is added by this research. The existing [memory-counter mitigation](../mitigations/system-memory-counters.md)
targets VM flavors and does not normalize `HOST_CPU_LOAD_INFO`.

## Official Links

Reviewed on 2026-09-29. XNU references below are pinned to the
`xnu-12377.1.9` source import, commit
`f6217f891ac0bb64f3d375211650a4c1ff8ca1ea`. This is a reference implementation,
not evidence that every supported iOS release or sandbox has identical behavior.

- [Apple `host_processor_info` declaration](https://developer.apple.com/documentation/kernel/1502854-host_processor_info).
- [XNU CPU resource-accounting overview][xnu-recount].
- [XNU processor flavor and count definitions][xnu-processor-info],
  [host flavor and count definitions][xnu-host-info], and
  [CPU state ordering][xnu-machine].
- [XNU processor tick conversion][xnu-processor] and
  [host aggregation, caching, and out-of-line allocation][xnu-host].
- [XNU task accounting structures][xnu-task-info] and
  [task accounting implementation][xnu-task].
- [XNU thread structures and usage scale][xnu-thread-info] and
  [thread scheduler-usage implementation][xnu-thread].
- [XNU Mach host interface][xnu-mach-host] and
  [out-of-line array types][xnu-mach-types].
- [XNU task-thread port and array cleanup example][xnu-thread-cleanup].
- [Apple archived `getrusage(2)` iOS manual](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/getrusage.2.html).
- [Apple Mach timebase and sleep semantics](https://developer.apple.com/documentation/driverkit/c-runtime-support).

## Loupe Signals and Binary Extensions

| Signal | Source API / collector | Classification | Decision | Fingerprinting value |
| --- | --- | --- | --- | --- |
| Per-processor user/system/idle/nice ticks | Supplied `getAllProcessorsCpuUsage:` uses `host_processor_info(..., PROCESSOR_CPU_LOAD_INFO, ...)` | Passive cumulative shared system state | Research; implementation deferred | Exact counter tuples and successive deltas can reveal shared device workload. |
| Aggregate CPU ticks | Adjacent `host_statistics(..., HOST_CPU_LOAD_INFO, ...)`; also investigate the `host_statistics64` entry point | Passive cumulative shared system state | Research with per-processor counters | Alternate observation of the same accounting domain. Not identified as an app call in the supplied analysis. |
| Current-process CPU | Supplied `getCpuUsageForTaskSelf` calls `task_info` | Passive task accounting | Research; verify actual flavor and calculation | Primarily the app's own work; weaker cross-app value and higher profiling compatibility cost. |
| Live-thread and terminated-thread times | Adjacent `TASK_THREAD_TIMES_INFO` and basic-task flavors, including `MACH_TASK_BASIC_INFO` | Passive task accounting | Coherence and bypass research | Different lifetime partitions must not be mistaken for one total. |
| Total and live-thread Mach times | Adjacent `TASK_ABSOLUTETIME_INFO` and CPU-time fields in `TASK_POWER_INFO` | Passive task accounting | Coherence and bypass research | Higher-resolution paths can retain precision after a narrower hook. |
| Per-thread CPU | Adjacent `task_threads` plus `thread_info(THREAD_BASIC_INFO)` / `THREAD_EXTENDED_INFO` | Passive thread accounting | Coherence and bypass research | Exposes cumulative times and a separate scaled scheduler-usage estimate. These calls are not established for the analyzed helper. |
| BSD task/thread accounting | Adjacent `getrusage(RUSAGE_SELF)`, `proc_pidinfo` task/thread flavors, `proc_pid_rusage`, and thread self-accounting where available | Passive self or permission-limited process accounting | Inventory only; availability unresolved | Independent APIs can cross-check CPU work. No coverage claim for these paths. |
| Processor count | Reviewed Loupe `ProcessInfo.processorCount`; binary `hw.*cpu` reads | Hardware/topology read | Exclude as a standalone CPU-load target | Constrains returned array shape and total capacity. |

The [XNU accounting overview][xnu-recount] identifies Mach, BSD, task, thread,
and processor interfaces backed by related accounting. Their appearance in XNU
does not establish normal iOS-app access or prove the supplied binary uses them.

### Counter and Delta Semantics

`PROCESSOR_CPU_LOAD_INFO` returns four tick fields per processor, in the order
user, system, idle, nice. Its count is a count of Mach integer elements, not
bytes or processors. The load structures use 32-bit fields; interpret their
bits as unsigned accounting values even when the returned array type is
`integer_t *`. See the [processor header][xnu-processor-info],
[host header][xnu-host-info], and [state definitions][xnu-machine].

In the reviewed [processor implementation][xnu-processor], accounted time is
converted using the scheduler tick interval. These ticks are neither CPU cycles
nor raw `mach_absolute_time` units. Nice ticks are explicitly zero in this
snapshot; do not synthesize a nonzero nice stream without evidence for the
target OS. Aggregate host CPU fields sum processor contributions; the reviewed
`host_statistics64` implementation also forwards this flavor to
`host_statistics`. Its name does not make these CPU fields 64-bit.
[XNU host implementation][xnu-host]

The supplied collector retains earlier tick arrays and computes differences.
For two valid samples with the same processor topology and accounting epoch:

```text
delta[i, state] = unsigned_difference(current[i, state], previous[i, state])
total[i] = delta[i, user] + delta[i, system] + delta[i, idle] + delta[i, nice]
busy[i] = delta[i, user] + delta[i, system] + delta[i, nice]
utilization[i] = busy[i] / total[i], only when total[i] > 0
aggregate_utilization = sum(busy[i]) / sum(total[i])
```

Use a wider accumulator for totals. A first sample supplies a baseline; a
percentage from that sample alone describes accumulated history, not a recent
interval. Zero deltas are valid. Modular subtraction handles a single known
32-bit wrap, but cannot distinguish arbitrary multiple wraps, a reboot, or a
topology change. Those cases need explicit baseline handling. A static offset
leaves deltas exposed; independent per-call noise can create negative or
implausible differences.

Task accounting is different. Basic-task CPU times cover terminated threads;
`TASK_THREAD_TIMES_INFO` covers live threads and can decrease when a thread exits.
Total task accounting includes both partitions. Separate reads race with
execution and thread exit; exact equality is not guaranteed. See
[XNU task accounting][xnu-task]. `THREAD_BASIC_INFO.cpu_usage` is scaled by
`TH_USAGE_SCALE` (`1000`), with scheduler aging in the reviewed implementation;
it is not a cumulative tick counter. See the [thread header][xnu-thread-info]
and [scheduler calculation][xnu-thread]. Keep `time_value_t` seconds/microseconds,
Mach-unit task times, and extended-thread nanosecond times distinct when comparing
APIs. Summed thread usage can exceed 100% under the convention where one fully
busy core is 100%.

### Analysis Correction

Section 5 labels the Google Ads memory query `TASK_VM_INFO = 0x14`. The
[task header][xnu-task-info] defines `MACH_TASK_BASIC_INFO = 20` (`0x14`) and
`TASK_VM_INFO = 22` (`0x16`). If the disassembly actually passes `0x14`, inspect
it as basic-task information, not a `task_vm_info` footprint structure. Confirm
the immediate flavor, count, and read offsets before attributing either memory
or CPU fields. The analysis gives no exact flavor for `getCpuUsageForTaskSelf`.

## Permission and Collection Class

These are passive local reads with no TCC permission prompt. The Mach host
interface accepts an ordinary host port for `host_processor_info`; that differs
from obtaining individual processor ports through privileged `host_processors`.
Self-task and self-thread inspection differs from inspecting other processes,
which requires appropriate rights and may fail under sandbox or entitlement
policy. A future hook must preserve those failures.
[XNU Mach host interface][xnu-mach-host]

Kernel declarations alone do not establish SDK export availability, successful
sandboxed execution, or identical accounting on all OS/device combinations.
Test actual symbols, flavors, returned counts, architectures, and port rights.
The supplied binary is evidence of collector code, not measured successful
collection. Simulator/macOS results do not establish physical-iPhone behavior.

The reviewed host implementation rate-limits third-party host-statistics reads
and can return cached samples. Separate aggregate and per-processor reads need
not represent the same instant; a zero delta or bounded mismatch can be genuine
collection behavior. Preserve this distinction when defining validation
tolerances. [XNU host caching][xnu-host]

## Fingerprinting Value

Working hypothesis: cumulative global tick tuples expose device history, while
high-frequency deltas can correlate apps observing the same shared workload.
An app can also induce CPU work and compare the resulting trace. Neither
correlation strength nor a dependable cross-app identifier has been measured
here. Per-task counters mostly expose known self-work, but provide useful checks
against a fabricated global trace. Active timing remains an independent
observation even if all listed accounting getters are shaped.

## Mitigation Strategy Ideas

Implementation is deferred. A future experiment should start with the paired
global surfaces, not broaden silently into task/thread profiling. Compare
coarse, commonly shared workload bands against synthetic trajectories before
choosing a policy; a distinctive seeded waveform can itself become a tracker.

Use one mitigation-owned counter model for per-processor and aggregate outputs.
Internally retain wide cumulative values with nonnegative increments, then
serialize at the API's native width. Define aggregate fields as the modulo-width
sum of the same processor state. Derive progress from elapsed monotonic time
and a documented epoch, not the number or order of queries. Repeated reads in
one sampling window should be stable; concurrent reads must publish complete
snapshots. Preserve topology, field order, native zero fields, counts, success
codes, and unsupported-flavor behavior.

If task/thread shaping is later considered, model live and terminated partitions
and rollover on thread exit together. Do not require the live-thread sum itself
to be monotonic. Account for thread churn, reused port names, and snapshot races.
Scheduler-usage fields need their own age/scale semantics tied to that accounting
model; they cannot be filled with the cumulative tick values.

### Buffer Ownership and Hook Composition

The Mach interface returns processor data as an out-of-line integer array.
The supplied collector releases it with `vm_deallocate`. A future replacement
should call the original, validate success and the returned pointer/count/shape,
then modify only the documented elements in the original allocation. Check
`processorCount * PROCESSOR_CPU_LOAD_INFO_COUNT` and the conversion to byte size
with overflow-safe arithmetic; an unexpected array shape must pass through. Preserve
caller ownership: its release size is the returned element count multiplied by
`sizeof(integer_t)` in the caller's task, not the number of cores. Never
substitute stack/static/`malloc` storage or deallocate the buffer before return.
See the [Mach interface][xnu-mach-host] and [array type][xnu-mach-types].

Host/task/thread info writes use caller-provided storage and count contracts;
they do not all allocate like `host_processor_info`. Adjacent `task_threads`
returns both an out-of-line array and thread port rights: a validation harness
must release the acquired rights as well as the array, including partial-error
cleanup. The [XNU cleanup test][xnu-thread-cleanup] demonstrates releasing each
thread right and then the array. Repeated probes must not grow VM mappings or
leak ports.

A future CPU module would share `host_statistics*` entry points with the memory
module. Verify hook composition so CPU handling preserves VM flavors and memory
handling preserves CPU flavors, with no recursive or duplicate shaping. Test
imported calls, direct symbol calls, and late-loaded images supported by the hook
backend. Direct Mach messages or other unhooked paths remain potential bypasses.

## Derivation Considerations

Keep ownership in the future CPU mitigation under `src/mitigations/`; generic
helpers belong in `src/mitigationkit/` and must not declare policy seeds. Declare
value and state domains with `LH_POLICY_SEED` in source only when implementation
is authorized. Runtime derivation must use generated bytes with the active seed
and `LHScope`, through `LHMitigationValues.h`. This page reserves no identifiers
and adds no catalog metadata or centralized value/state registry.

Preserve the existing install, app, vendor, and manual linked-group scopes.
Document the model's epoch, counters, time anchor, sampling phase, processor
topology, schema version, and checkpoint lifetime. For a shared scope, separate
processes must reproduce the same time-indexed model or synchronize state
updates; the current state-provider API must be assessed before assuming atomic
counter updates across processes. A process-local reset on each launch would
contradict counters that appear to describe a device lifetime.

Define behavior for relaunch, real reboot, seed/scope rotation, schema changes,
topology changes, state loss, and toggling policy while an app retains a baseline.
Do not resume one synthetic stream against a real or unrelated prior baseline.
The transition contract and required app restart need evaluation before shipping.

Coordinate the initial counter age with the existing [boot-time owner](../mitigations/system-boot-time.md)
and its documented dependencies, without introducing shared mitigation-owned
state modules. Keep processor count consistent with [System Info](system-info.md)
and hardware observations. Use an unmodified monotonic clock for internal
intervals; wall-clock changes must not make counters run backward. Mach absolute
time excludes system sleep whereas continuous time includes it, so define and
validate suspend/sleep behavior instead of adding idle ticks for all elapsed
wall time. Do not globally alter clocks to conceal load or benchmark results.

## Impact and Tradeoffs

CPU displays, profilers, diagnostics, adaptive workloads, and battery reporting
can lose useful accuracy. A global synthetic idle trace can contradict an app's
own busy benchmark and real thermal, power, or timing observations. The memory
and network counters describe different resources: numerical equality is not a
coherence requirement, but impossible combined workload stories are a detection
risk. Reducing precision cannot guarantee removal of workload correlation.

On original failure, unsupported flavor, malformed shape, unavailable state, or
an unsafe transition, preserve original behavior. If a future experiment cannot
maintain the documented model coherently, leave it disabled. No fallback or
rollback implementation is supplied here.

### Validation Proposal

These checks are proposed, not completed:

1. Run an uninjected physical-device harness using the supplied collector's
   per-core path and adjacent aggregate/task/thread paths. Record SDK, OS,
   device/architecture, sandbox, port rights, return codes, counts, nice fields,
   and observed cadence. Verify the analyzed task flavor and field offsets.
2. Compare repeated and interval samples at idle, during known single-thread and
   multi-thread work, after thread exit, and across backgrounding, suspend/sleep,
   and resume. Distinguish cache plateaus from failures; measure aggregate versus
   per-core disagreement over closely timed reads rather than demand equality.
3. For a future model, check nonnegative wide increments, native-width wrap,
   zero-delta handling, topology changes, same-window consistency, query-order
   independence, and concurrent complete snapshots. Check weighted utilization
   and capacity bounds using the measured tick/time semantics.
4. Exercise allocation/count failures, unsupported flavors, malformed returned
   shapes in fixtures, repeated `vm_deallocate` cleanup, and task-thread port
   cleanup. Confirm no out-of-bounds writes, VM leaks, or port growth.
5. Test memory/CPU hook composition, boot-time and processor-count agreement,
   relaunch and shared-scope consistency, real reboot, schema/state failure,
   seed rotation, and disable/re-enable with a retained consumer baseline.
6. Compare simultaneous observations from apps in separate and deliberately
   shared scopes, including induced workload. Evaluate correlation reduction and
   whether synthetic traces add uniqueness. Document remaining direct-Mach,
   BSD, task/thread, hardware, and active-timing observations.

## Exclusion Note

The binary's hardware database supplies nominal `cpuFrequency`; `hw.tbfrequency`
is a timebase frequency, not proof of a current CPU clock. CPU counts,
architecture, cache sizes, pagesize, and RAM tier belong with hardware coherence.
They are not independent CPU-load mitigation targets.

The analyzed frequency routine runs and times worker-thread work with
`mach_absolute_time`, pthread/Mach thread control, and dispatch scheduling.
Its estimated effective frequency depends on execution throughput and timing.
Shaping CPU-accounting getters does not conceal that measurement. Benchmark or
hardware-profile work would require separate research and authorization.

## Relevance

CPU load remains a documented research candidate. Global cumulative accounting
is more directly relevant to shared-device workload than self-task CPU
profiling, but compatibility and cross-API coherence require measurement before
implementation. CPU-load implementation is explicitly deferred; this page
does not change the selected mitigation set or claim coverage.

[xnu-recount]: https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/doc/observability/recount.md
[xnu-processor-info]: https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/osfmk/mach/processor_info.h
[xnu-host-info]: https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/osfmk/mach/host_info.h
[xnu-machine]: https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/osfmk/mach/machine.h
[xnu-processor]: https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/osfmk/kern/processor.c
[xnu-host]: https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/osfmk/kern/host.c
[xnu-task-info]: https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/osfmk/mach/task_info.h
[xnu-task]: https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/osfmk/kern/task.c
[xnu-thread-info]: https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/osfmk/mach/thread_info.h
[xnu-thread]: https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/osfmk/kern/thread.c
[xnu-mach-host]: https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/osfmk/mach/mach_host.defs
[xnu-mach-types]: https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/osfmk/mach/mach_types.defs
[xnu-thread-cleanup]: https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/tests/imm_pinned_control_port.c
