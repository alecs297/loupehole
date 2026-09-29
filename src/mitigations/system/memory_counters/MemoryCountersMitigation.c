#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"

#include <dlfcn.h>
#include <mach/host_info.h>
#include <mach/mach.h>
#include <mach/task_info.h>
#include <mach/vm_statistics.h>
#include <stdint.h>
#include <stddef.h>
#include <string.h>

typedef kern_return_t (*LHHostStatisticsOriginal)(host_t host, host_flavor_t flavor, host_info_t info, mach_msg_type_number_t *count);
typedef kern_return_t (*LHHostStatistics64Original)(host_t host, host_flavor_t flavor, host_info64_t info, mach_msg_type_number_t *count);
typedef uint64_t (*LHOSProcAvailableMemoryOriginal)(void);
typedef kern_return_t (*LHTaskInfoOriginal)(task_name_t task, task_flavor_t flavor, task_info_t info, mach_msg_type_number_t *count);

LH_POLICY_SEED(system_memory_counter_noise)
LH_POLICY_SEED(process_memory_counter_precision)

static LHHostStatisticsOriginal LHMemoryHostStatisticsOriginalImplementation;
static LHHostStatistics64Original LHMemoryHostStatistics64OriginalImplementation;
static LHOSProcAvailableMemoryOriginal LHMemoryOSProcAvailableMemoryOriginalImplementation;
static LHTaskInfoOriginal LHMemoryTaskInfoOriginalImplementation;
static LHPolicyEngine *LHMemoryPolicy;

static uint64_t LHMemoryDeriveNoise(const char *fieldName, uint64_t value, uint64_t maxNoise) {
    if (LHMemoryPolicy == 0 || fieldName == 0 || maxNoise == 0) {
        return 0;
    }

    uint64_t derived = 0;
    if (!LHMitigationDeriveBoundedU64(&LHMemoryPolicy->config.buildSeed,
                                      &LHGeneratedPolicySeed_system_memory_counter_noise,
                                      &LHMemoryPolicy->appContext.scope,
                                      (const uint8_t *)fieldName,
                                      strlen(fieldName),
                                      maxNoise + 1,
                                      &derived)) {
        return 0;
    }

    uint64_t live = (value ^ (value >> 7) ^ (value >> 17)) % (maxNoise + 1);
    return (derived + live) % (maxNoise + 1);
}

static uint64_t LHMemoryShapeU64(const char *fieldName, uint64_t value, uint64_t cap) {
    if (value < 8 || cap == 0) {
        return value;
    }

    uint64_t proportional = value / 64;
    uint64_t maxNoise = proportional == 0 ? 1 : proportional;
    if (maxNoise > cap) {
        maxNoise = cap;
    }

    uint64_t noise = LHMemoryDeriveNoise(fieldName, value, maxNoise);
    if (noise >= value) {
        return value;
    }
    return value - noise;
}

static natural_t LHMemoryShapeNatural(const char *fieldName, natural_t value, uint64_t cap) {
    return (natural_t)LHMemoryShapeU64(fieldName, value, cap);
}

static void LHMemoryShapeVMStatistics(vm_statistics_t stats) {
    if (stats == 0) {
        return;
    }

    stats->free_count = LHMemoryShapeNatural("free_count", stats->free_count, 255);
    stats->active_count = LHMemoryShapeNatural("active_count", stats->active_count, 255);
    stats->inactive_count = LHMemoryShapeNatural("inactive_count", stats->inactive_count, 255);
    stats->wire_count = LHMemoryShapeNatural("wire_count", stats->wire_count, 255);
    stats->pageins = LHMemoryShapeNatural("pageins", stats->pageins, 4095);
    stats->pageouts = LHMemoryShapeNatural("pageouts", stats->pageouts, 4095);
    stats->faults = LHMemoryShapeNatural("faults", stats->faults, 8191);
    stats->cow_faults = LHMemoryShapeNatural("cow_faults", stats->cow_faults, 8191);
    stats->purgeable_count = LHMemoryShapeNatural("purgeable_count", stats->purgeable_count, 255);
    stats->purges = LHMemoryShapeNatural("purges", stats->purges, 4095);
    stats->speculative_count = LHMemoryShapeNatural("speculative_count", stats->speculative_count, 255);
}

static bool LHMemoryCountIncludesBytes(mach_msg_type_number_t count, size_t byteCount) {
    return ((size_t)count * sizeof(integer_t)) >= byteCount;
}

#define LH_MEMORY_COUNT_INCLUDES_FIELD(count, type, field) \
    LHMemoryCountIncludesBytes((count), offsetof(type, field) + sizeof(((type *)0)->field))

static uint64_t LHMemoryProcessQuantum(void) {
    uint64_t derived = 0;
    if (LHMemoryPolicy == 0 ||
        !LHMitigationDeriveBoundedU64(&LHMemoryPolicy->config.buildSeed,
                                     &LHGeneratedPolicySeed_process_memory_counter_precision,
                                     &LHMemoryPolicy->appContext.scope,
                                     0, 0, 13, &derived)) {
        return 0;
    }
    return (4 + derived) * 16ULL * 1024ULL;
}

static uint64_t LHMemoryReduceProcessPrecision(uint64_t value, uint64_t quantum) {
    return quantum == 0 ? value : value - value % quantum;
}

/* One monotone rounding rule preserves equal values and current/peak ordering. */
#define LH_MEMORY_PROCESS_FIELD(type, field) \
    do { \
        if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, type, field)) { \
            stats->field = LHMemoryReduceProcessPrecision(stats->field, quantum); \
        } \
    } while (0)

#define LH_MEMORY_PROCESS_SIGNED_FIELD(field) \
    do { \
        if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct task_vm_info, field) && stats->field > 0) { \
            stats->field = (int64_t)LHMemoryReduceProcessPrecision((uint64_t)stats->field, quantum); \
        } \
    } while (0)

static void LHMemoryShapeTaskVMInfo(task_vm_info_t stats, mach_msg_type_number_t count, uint64_t quantum) {
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, virtual_size);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, resident_size);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, resident_size_peak);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, device);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, device_peak);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, internal);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, internal_peak);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, external);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, external_peak);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, reusable);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, reusable_peak);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, purgeable_volatile_pmap);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, purgeable_volatile_resident);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, purgeable_volatile_virtual);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, compressed);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, compressed_peak);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, compressed_lifetime);
    LH_MEMORY_PROCESS_FIELD(struct task_vm_info, phys_footprint);
#ifdef TASK_VM_INFO_REV3_COUNT
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_phys_footprint_peak);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_purgeable_nonvolatile);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_purgeable_novolatile_compressed);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_purgeable_volatile);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_purgeable_volatile_compressed);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_network_nonvolatile);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_network_nonvolatile_compressed);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_network_volatile);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_network_volatile_compressed);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_media_footprint);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_media_footprint_compressed);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_media_nofootprint);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_media_nofootprint_compressed);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_graphics_footprint);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_graphics_footprint_compressed);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_graphics_nofootprint);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_graphics_nofootprint_compressed);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_neural_footprint);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_neural_footprint_compressed);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_neural_nofootprint);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_neural_nofootprint_compressed);
#endif
#ifdef TASK_VM_INFO_REV4_COUNT
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct task_vm_info, limit_bytes_remaining)) {
        stats->limit_bytes_remaining = LHMemoryShapeU64("os_proc_available_memory", stats->limit_bytes_remaining,
                                                       32ULL * 1024ULL * 1024ULL);
    }
#endif
#ifdef TASK_VM_INFO_REV7_COUNT
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_neural_nofootprint_total);
    LH_MEMORY_PROCESS_SIGNED_FIELD(ledger_tag_neural_nofootprint_peak);
#endif
}

static kern_return_t LHMemoryTaskInfoReplacement(task_name_t task, task_flavor_t flavor, task_info_t info,
                                               mach_msg_type_number_t *count) {
    if (LHMemoryTaskInfoOriginalImplementation == 0) {
        return KERN_FAILURE;
    }

    mach_msg_type_number_t capacity = count == 0 ? 0 : *count;
    kern_return_t result = LHMemoryTaskInfoOriginalImplementation(task, flavor, info, count);
    if (result != KERN_SUCCESS || task != mach_task_self() || info == 0 || count == 0) {
        return result;
    }
    if (flavor != MACH_TASK_BASIC_INFO && flavor != TASK_BASIC_INFO_32 && flavor != TASK_BASIC_INFO_64 &&
        flavor != TASK_VM_INFO && flavor != TASK_VM_INFO_PURGEABLE) {
        return result;
    }

    /* Do not trust a returned revision to exceed the original caller capacity. */
    mach_msg_type_number_t readableCount = *count < capacity ? *count : capacity;
    uint64_t quantum = LHMemoryProcessQuantum();
    if (quantum == 0) {
        return result;
    }

    switch (flavor) {
        case MACH_TASK_BASIC_INFO: {
            mach_task_basic_info_t stats = (mach_task_basic_info_t)info;
            mach_msg_type_number_t count = readableCount;
            LH_MEMORY_PROCESS_FIELD(struct mach_task_basic_info, virtual_size);
            LH_MEMORY_PROCESS_FIELD(struct mach_task_basic_info, resident_size);
            LH_MEMORY_PROCESS_FIELD(struct mach_task_basic_info, resident_size_max);
            break;
        }
        case TASK_BASIC_INFO_32: {
            task_basic_info_32_t stats = (task_basic_info_32_t)info;
            mach_msg_type_number_t count = readableCount;
            LH_MEMORY_PROCESS_FIELD(struct task_basic_info_32, virtual_size);
            LH_MEMORY_PROCESS_FIELD(struct task_basic_info_32, resident_size);
            break;
        }
        case TASK_BASIC_INFO_64: {
            task_basic_info_64_t stats = (task_basic_info_64_t)info;
            mach_msg_type_number_t count = readableCount;
            LH_MEMORY_PROCESS_FIELD(struct task_basic_info_64, virtual_size);
            LH_MEMORY_PROCESS_FIELD(struct task_basic_info_64, resident_size);
            break;
        }
        case TASK_VM_INFO:
        case TASK_VM_INFO_PURGEABLE:
            LHMemoryShapeTaskVMInfo((task_vm_info_t)info, readableCount, quantum);
            break;
        default:
            break;
    }
    return result;
}

#undef LH_MEMORY_PROCESS_FIELD
#undef LH_MEMORY_PROCESS_SIGNED_FIELD

static void LHMemoryShapeVMStatistics64(vm_statistics64_t stats, mach_msg_type_number_t count) {
    if (stats == 0) {
        return;
    }

    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, free_count)) {
        stats->free_count = LHMemoryShapeNatural("free_count", stats->free_count, 255);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, active_count)) {
        stats->active_count = LHMemoryShapeNatural("active_count", stats->active_count, 255);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, inactive_count)) {
        stats->inactive_count = LHMemoryShapeNatural("inactive_count", stats->inactive_count, 255);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, wire_count)) {
        stats->wire_count = LHMemoryShapeNatural("wire_count", stats->wire_count, 255);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, pageins)) {
        stats->pageins = LHMemoryShapeU64("pageins", stats->pageins, 4095);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, pageouts)) {
        stats->pageouts = LHMemoryShapeU64("pageouts", stats->pageouts, 4095);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, faults)) {
        stats->faults = LHMemoryShapeU64("faults", stats->faults, 8191);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, cow_faults)) {
        stats->cow_faults = LHMemoryShapeU64("cow_faults", stats->cow_faults, 8191);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, purgeable_count)) {
        stats->purgeable_count = LHMemoryShapeNatural("purgeable_count", stats->purgeable_count, 255);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, purges)) {
        stats->purges = LHMemoryShapeU64("purges", stats->purges, 4095);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, speculative_count)) {
        stats->speculative_count = LHMemoryShapeNatural("speculative_count", stats->speculative_count, 255);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, decompressions)) {
        stats->decompressions = LHMemoryShapeU64("decompressions64", stats->decompressions, 4095);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, compressions)) {
        stats->compressions = LHMemoryShapeU64("compressions64", stats->compressions, 4095);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, swapins)) {
        stats->swapins = LHMemoryShapeU64("swapins64", stats->swapins, 4095);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, swapouts)) {
        stats->swapouts = LHMemoryShapeU64("swapouts64", stats->swapouts, 4095);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, compressor_page_count)) {
        stats->compressor_page_count = LHMemoryShapeNatural("compressor_page_count64", stats->compressor_page_count, 255);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, throttled_count)) {
        stats->throttled_count = LHMemoryShapeNatural("throttled_count64", stats->throttled_count, 255);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, external_page_count)) {
        stats->external_page_count = LHMemoryShapeNatural("external_page_count64", stats->external_page_count, 255);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, internal_page_count)) {
        stats->internal_page_count = LHMemoryShapeNatural("internal_page_count64", stats->internal_page_count, 255);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, total_uncompressed_pages_in_compressor)) {
        stats->total_uncompressed_pages_in_compressor = LHMemoryShapeU64("total_uncompressed_pages_in_compressor64", stats->total_uncompressed_pages_in_compressor, 255);
    }
    if (LH_MEMORY_COUNT_INCLUDES_FIELD(count, struct vm_statistics64, swapped_count)) {
        stats->swapped_count = LHMemoryShapeU64("swapped_count64", stats->swapped_count, 255);
    }
}

static kern_return_t LHMemoryHostStatisticsReplacement(host_t host, host_flavor_t flavor, host_info_t info, mach_msg_type_number_t *count) {
    if (LHMemoryHostStatisticsOriginalImplementation == 0) {
        return KERN_FAILURE;
    }

    kern_return_t result = LHMemoryHostStatisticsOriginalImplementation(host, flavor, info, count);
    if (result == KERN_SUCCESS && flavor == HOST_VM_INFO && info != 0 && count != 0 && *count >= HOST_VM_INFO_COUNT) {
        LHMemoryShapeVMStatistics((vm_statistics_t)info);
    }
    return result;
}

static kern_return_t LHMemoryHostStatistics64Replacement(host_t host, host_flavor_t flavor, host_info64_t info, mach_msg_type_number_t *count) {
    if (LHMemoryHostStatistics64OriginalImplementation == 0) {
        return KERN_FAILURE;
    }

    kern_return_t result = LHMemoryHostStatistics64OriginalImplementation(host, flavor, info, count);
    if (result == KERN_SUCCESS && flavor == HOST_VM_INFO64 && info != 0 && count != 0) {
        LHMemoryShapeVMStatistics64((vm_statistics64_t)info, *count);
    }
    return result;
}

static uint64_t LHMemoryOSProcAvailableMemoryReplacement(void) {
    if (LHMemoryOSProcAvailableMemoryOriginalImplementation == 0) {
        return 0;
    }

    uint64_t original = LHMemoryOSProcAvailableMemoryOriginalImplementation();
    return LHMemoryShapeU64("os_proc_available_memory", original, 32ULL * 1024ULL * 1024ULL);
}

bool LHMitigation_system_memory_counters_mach_bucketed_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHMemoryPolicy = policy;

    bool installed = false;
    void *hostStats = dlsym(RTLD_DEFAULT, "host_statistics");
    if (hostStats != 0) {
        installed = LHHookBackendHookFunction(backend,
                                              hostStats,
                                              (void *)LHMemoryHostStatisticsReplacement,
                                              (void **)&LHMemoryHostStatisticsOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "host_statistics",
                                                (void *)LHMemoryHostStatisticsReplacement,
                                                (void **)&LHMemoryHostStatisticsOriginalImplementation) || installed;

    void *hostStats64 = dlsym(RTLD_DEFAULT, "host_statistics64");
    if (hostStats64 != 0) {
        installed = LHHookBackendHookFunction(backend,
                                              hostStats64,
                                              (void *)LHMemoryHostStatistics64Replacement,
                                              (void **)&LHMemoryHostStatistics64OriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "host_statistics64",
                                                (void *)LHMemoryHostStatistics64Replacement,
                                                (void **)&LHMemoryHostStatistics64OriginalImplementation) || installed;

    void *availableMemory = dlsym(RTLD_DEFAULT, "os_proc_available_memory");
    if (availableMemory != 0) {
        installed = LHHookBackendHookFunction(backend,
                                              availableMemory,
                                              (void *)LHMemoryOSProcAvailableMemoryReplacement,
                                              (void **)&LHMemoryOSProcAvailableMemoryOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "os_proc_available_memory",
                                                (void *)LHMemoryOSProcAvailableMemoryReplacement,
                                                (void **)&LHMemoryOSProcAvailableMemoryOriginalImplementation) || installed;

    installed = LHHookBackendHookImportedSymbol(backend,
                                                "task_info",
                                                (void *)LHMemoryTaskInfoReplacement,
                                                (void **)&LHMemoryTaskInfoOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_system_memory_counters_mach_bucketed);
    }
    return true;
}
