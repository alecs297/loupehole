#include <assert.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>

#include "../../mitigations/system/memory_counters/MemoryCountersMitigation.c"

/* Fixed test policy bytes allow checks before the normal generator runs. */
const LHPolicySeed LHGeneratedPolicySeed_system_memory_counter_noise = { .bytes = { 1 } };
const LHPolicySeed LHGeneratedPolicySeed_process_memory_counter_precision = { .bytes = { 2 } };

static unsigned char LHTestOriginalData[TASK_INFO_MAX * sizeof(integer_t)];
static mach_msg_type_number_t LHTestReturnedCount;
static kern_return_t LHTestResult;
static unsigned LHTestOriginalCalls;
static bool LHTestAcceptTaskHook;
static unsigned LHTestTaskHooks;
static unsigned LHTestNoOps;
static unsigned LHTestStateCalls;

bool LHPolicyEngineLoadOrCreateState(const LHPolicyEngine *engine, const LHStateKey *key,
                                    uint8_t *output, size_t outputLength,
                                    LHStateGenerateBytes generate, void *generatorContext,
                                    LHStateLoadResult *result) {
    (void)engine; (void)key; (void)output; (void)outputLength;
    (void)generate; (void)generatorContext; (void)result;
    LHTestStateCalls++;
    return false;
}

static kern_return_t LHTestTaskInfo(task_name_t task, task_flavor_t flavor, task_info_t info,
                                  mach_msg_type_number_t *count) {
    (void)task; (void)flavor;
    LHTestOriginalCalls++;
    if (count != 0) {
        mach_msg_type_number_t writableCount = *count < LHTestReturnedCount ? *count : LHTestReturnedCount;
        if (info != 0) {
            assert((size_t)writableCount * sizeof(integer_t) <= sizeof(LHTestOriginalData));
            memcpy(info, LHTestOriginalData, (size_t)writableCount * sizeof(integer_t));
        }
        *count = LHTestReturnedCount;
    }
    return LHTestResult;
}

static bool LHTestFunctionHook(LHHookBackend *backend, void *target, void *replacement, void **original) {
    (void)backend; (void)replacement; (void)original;
    assert(target != dlsym(RTLD_DEFAULT, "task_info"));
    return false;
}

static bool LHTestImportedHook(LHHookBackend *backend, const char *symbol, void *replacement, void **original) {
    (void)backend;
    if (strcmp(symbol, "task_info") != 0) {
        return false;
    }
    LHTestTaskHooks++;
    assert(replacement == (void *)LHMemoryTaskInfoReplacement);
    if (LHTestAcceptTaskHook) {
        *original = (void *)LHTestTaskInfo;
    }
    return LHTestAcceptTaskHook;
}

static bool LHTestNoOp(LHHookBackend *backend, uint32_t moduleID) {
    (void)backend;
    assert(moduleID == LHModuleID_system_memory_counters_mach_bucketed);
    LHTestNoOps++;
    return true;
}

typedef enum LHTestFieldKind { LHTestU32, LHTestU64, LHTestI64, LHTestAvailable } LHTestFieldKind;
typedef struct LHTestField { size_t offset; LHTestFieldKind kind; } LHTestField;

#define VM_FIELD(field) { offsetof(struct task_vm_info, field), LHTestU64 }
#define LEDGER_FIELD(field) { offsetof(struct task_vm_info, field), LHTestI64 }
static const LHTestField LHTestVMFields[] = {
    VM_FIELD(virtual_size), VM_FIELD(resident_size), VM_FIELD(resident_size_peak),
    VM_FIELD(device), VM_FIELD(device_peak), VM_FIELD(internal), VM_FIELD(internal_peak),
    VM_FIELD(external), VM_FIELD(external_peak), VM_FIELD(reusable), VM_FIELD(reusable_peak),
    VM_FIELD(purgeable_volatile_pmap), VM_FIELD(purgeable_volatile_resident),
    VM_FIELD(purgeable_volatile_virtual), VM_FIELD(compressed), VM_FIELD(compressed_peak),
    VM_FIELD(compressed_lifetime), VM_FIELD(phys_footprint),
#ifdef TASK_VM_INFO_REV3_COUNT
    LEDGER_FIELD(ledger_phys_footprint_peak), LEDGER_FIELD(ledger_purgeable_nonvolatile),
    LEDGER_FIELD(ledger_purgeable_novolatile_compressed), LEDGER_FIELD(ledger_purgeable_volatile),
    LEDGER_FIELD(ledger_purgeable_volatile_compressed), LEDGER_FIELD(ledger_tag_network_nonvolatile),
    LEDGER_FIELD(ledger_tag_network_nonvolatile_compressed), LEDGER_FIELD(ledger_tag_network_volatile),
    LEDGER_FIELD(ledger_tag_network_volatile_compressed), LEDGER_FIELD(ledger_tag_media_footprint),
    LEDGER_FIELD(ledger_tag_media_footprint_compressed), LEDGER_FIELD(ledger_tag_media_nofootprint),
    LEDGER_FIELD(ledger_tag_media_nofootprint_compressed), LEDGER_FIELD(ledger_tag_graphics_footprint),
    LEDGER_FIELD(ledger_tag_graphics_footprint_compressed), LEDGER_FIELD(ledger_tag_graphics_nofootprint),
    LEDGER_FIELD(ledger_tag_graphics_nofootprint_compressed), LEDGER_FIELD(ledger_tag_neural_footprint),
    LEDGER_FIELD(ledger_tag_neural_footprint_compressed), LEDGER_FIELD(ledger_tag_neural_nofootprint),
    LEDGER_FIELD(ledger_tag_neural_nofootprint_compressed),
#endif
#ifdef TASK_VM_INFO_REV4_COUNT
    { offsetof(struct task_vm_info, limit_bytes_remaining), LHTestAvailable },
#endif
#ifdef TASK_VM_INFO_REV7_COUNT
    LEDGER_FIELD(ledger_tag_neural_nofootprint_total), LEDGER_FIELD(ledger_tag_neural_nofootprint_peak),
#endif
};
#undef VM_FIELD
#undef LEDGER_FIELD

static void LHTestExpectedFields(unsigned char *expected, size_t readableBytes,
                                 const LHTestField *fields, size_t fieldCount, uint64_t quantum) {
    for (size_t index = 0; index < fieldCount; index++) {
        size_t width = fields[index].kind == LHTestU32 ? sizeof(uint32_t) : sizeof(uint64_t);
        if (fields[index].offset + width > readableBytes) {
            continue;
        }
        unsigned char *location = expected + fields[index].offset;
        uint64_t value = 0;
        memcpy(&value, location, width);
        if (fields[index].kind == LHTestI64 && (int64_t)value <= 0) {
            continue;
        }
        uint64_t shaped = fields[index].kind == LHTestAvailable
            ? LHMemoryShapeU64("os_proc_available_memory", value, 32ULL * 1024ULL * 1024ULL)
            : LHMemoryReduceProcessPrecision(value, quantum);
        memcpy(location, &shaped, width);
    }
}

/* Every integer boundary, including half of a 64-bit field, must preserve the tail. */
static void LHTestBoundaries(task_flavor_t flavor, mach_msg_type_number_t fullCount,
                             const LHTestField *fields, size_t fieldCount) {
    uint64_t quantum = LHMemoryProcessQuantum();
    assert(quantum >= 64 * 1024 && quantum <= 256 * 1024);
    for (mach_msg_type_number_t capacity = 0; capacity <= fullCount + 4; capacity++) {
        for (unsigned variant = 0; variant < 3; variant++) {
            LHTestReturnedCount = variant == 0 ? capacity : variant == 1 ? capacity / 2 : fullCount + 4;
            size_t size = (size_t)capacity * sizeof(integer_t);
            unsigned char *guarded = malloc(size + 16);
            unsigned char *expected = malloc(size + 16);
            assert(guarded != 0 && expected != 0);
            memset(guarded, 0xa5, size + 16);
            memcpy(expected, guarded, size + 16);
            size_t readable = (size_t)(capacity < LHTestReturnedCount ? capacity : LHTestReturnedCount)
                * sizeof(integer_t);
            memcpy(expected + 8, LHTestOriginalData, readable);
            LHTestExpectedFields(expected + 8, readable, fields, fieldCount, quantum);

            mach_msg_type_number_t count = capacity;
            unsigned calls = LHTestOriginalCalls;
            assert(LHMemoryTaskInfoReplacement(mach_task_self(), flavor, (task_info_t)(guarded + 8), &count)
                   == KERN_SUCCESS);
            assert(count == LHTestReturnedCount && LHTestOriginalCalls == calls + 1);
            assert(memcmp(guarded, expected, size + 16) == 0);
            free(expected);
            free(guarded);
        }
    }
}

static void LHTestPrecision(void) {
    for (uint64_t quantum = 64 * 1024; quantum <= 256 * 1024; quantum += 16 * 1024) {
        uint64_t previous = 0;
        for (uint64_t value = 0; value <= 3 * quantum + 1; value++) {
            uint64_t shaped = LHMemoryReduceProcessPrecision(value, quantum);
            assert(shaped <= value && value - shaped < quantum && shaped >= previous);
            assert(LHMemoryReduceProcessPrecision(shaped, quantum) == shaped);
            previous = shaped;
        }
        const uint64_t extremes[] = { UINT32_MAX, INT64_MAX, UINT64_MAX - 1, UINT64_MAX };
        for (size_t index = 0; index < sizeof(extremes) / sizeof(extremes[0]); index++) {
            uint64_t shaped = LHMemoryReduceProcessPrecision(extremes[index], quantum);
            assert(shaped <= extremes[index] && extremes[index] - shaped < quantum);
        }
    }
    assert(LHMemoryReduceProcessPrecision(UINT64_MAX, 0) == UINT64_MAX);
}

static uint64_t LHTestAvailableMemory(void) {
    return 900ULL * 1024 * 1024 + 49152;
}

static void LHTestCoherence(void) {
    task_vm_info_data_t vm = {0};
    vm.virtual_size = 9ULL * 1024 * 1024 * 1024 + 49152;
    vm.resident_size = 128ULL * 1024 * 1024 + 49152;
    vm.resident_size_peak = vm.resident_size + 16384;
    vm.internal = 96ULL * 1024 * 1024 + 49152;
    vm.external = vm.resident_size - vm.internal;
    vm.compressed = 4ULL * 1024 * 1024 + 8192;
    vm.compressed_peak = vm.compressed + 16384;
    vm.compressed_lifetime = vm.compressed_peak + 16384;
    vm.phys_footprint = vm.internal + vm.compressed;
    vm.region_count = 17;
    vm.page_size = 16384;
#ifdef TASK_VM_INFO_REV3_COUNT
    vm.ledger_phys_footprint_peak = (int64_t)vm.phys_footprint + 16384;
    vm.ledger_purgeable_nonvolatile = -1;
    vm.ledger_purgeable_volatile = INT64_MIN;
#endif
#ifdef TASK_VM_INFO_REV4_COUNT
    vm.limit_bytes_remaining = LHTestAvailableMemory();
#endif
    memset(LHTestOriginalData, 0xc7, sizeof(LHTestOriginalData));
    memcpy(LHTestOriginalData, &vm, sizeof(vm));
    LHTestBoundaries(TASK_VM_INFO, TASK_VM_INFO_COUNT, LHTestVMFields,
                     sizeof(LHTestVMFields) / sizeof(LHTestVMFields[0]));
    LHTestBoundaries(TASK_VM_INFO_PURGEABLE, TASK_VM_INFO_COUNT, LHTestVMFields,
                     sizeof(LHTestVMFields) / sizeof(LHTestVMFields[0]));

    LHTestReturnedCount = TASK_VM_INFO_COUNT;
    task_vm_info_data_t shaped;
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    assert(LHMemoryTaskInfoReplacement(mach_task_self(), TASK_VM_INFO, (task_info_t)&shaped, &count) == KERN_SUCCESS);
    assert(shaped.resident_size <= shaped.resident_size_peak);
    assert(shaped.compressed <= shaped.compressed_peak && shaped.compressed_peak <= shaped.compressed_lifetime);
    assert(shaped.internal + shaped.external <= shaped.resident_size);
    assert(shaped.internal + shaped.compressed <= shaped.phys_footprint);
    assert(shaped.region_count == vm.region_count && shaped.page_size == vm.page_size);
#ifdef TASK_VM_INFO_REV3_COUNT
    assert((uint64_t)shaped.ledger_phys_footprint_peak >= shaped.phys_footprint);
    assert(shaped.ledger_purgeable_nonvolatile == -1 && shaped.ledger_purgeable_volatile == INT64_MIN);
#endif
#ifdef TASK_VM_INFO_REV4_COUNT
    LHMemoryOSProcAvailableMemoryOriginalImplementation = LHTestAvailableMemory;
    assert(shaped.limit_bytes_remaining == LHMemoryOSProcAvailableMemoryReplacement());
#endif

    mach_task_basic_info_data_t basic = {0};
    basic.virtual_size = vm.virtual_size;
    basic.resident_size = vm.resident_size;
    basic.resident_size_max = vm.resident_size_peak;
    basic.user_time.seconds = 31;
    basic.system_time.microseconds = 998;
    basic.policy = 8;
    basic.suspend_count = 3;
    memcpy(LHTestOriginalData, &basic, sizeof(basic));
    const LHTestField basicFields[] = {
        { offsetof(struct mach_task_basic_info, virtual_size), LHTestU64 },
        { offsetof(struct mach_task_basic_info, resident_size), LHTestU64 },
        { offsetof(struct mach_task_basic_info, resident_size_max), LHTestU64 },
    };
    LHTestBoundaries(MACH_TASK_BASIC_INFO, MACH_TASK_BASIC_INFO_COUNT, basicFields, 3);
    LHTestReturnedCount = MACH_TASK_BASIC_INFO_COUNT;
    count = MACH_TASK_BASIC_INFO_COUNT;
    mach_task_basic_info_data_t shapedBasic;
    assert(LHMemoryTaskInfoReplacement(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&shapedBasic, &count)
           == KERN_SUCCESS);
    assert(shapedBasic.resident_size == shaped.resident_size);
    assert(shapedBasic.virtual_size == shaped.virtual_size);
    assert(shapedBasic.resident_size_max == shaped.resident_size_peak);

    task_basic_info_32_data_t basic32 = {0};
    basic32.virtual_size = 900 * 1024 * 1024 + 8192;
    basic32.resident_size = (uint32_t)vm.resident_size;
    basic32.user_time.microseconds = 738;
    memcpy(LHTestOriginalData, &basic32, sizeof(basic32));
    const LHTestField basic32Fields[] = {
        { offsetof(struct task_basic_info_32, virtual_size), LHTestU32 },
        { offsetof(struct task_basic_info_32, resident_size), LHTestU32 },
    };
    LHTestBoundaries(TASK_BASIC_INFO_32, TASK_BASIC_INFO_32_COUNT, basic32Fields, 2);

    task_basic_info_64_data_t basic64 = {0};
    basic64.virtual_size = vm.virtual_size;
    basic64.resident_size = vm.resident_size;
    basic64.system_time.seconds = 842;
    memcpy(LHTestOriginalData, &basic64, sizeof(basic64));
    const LHTestField basic64Fields[] = {
        { offsetof(struct task_basic_info_64, virtual_size), LHTestU64 },
        { offsetof(struct task_basic_info_64, resident_size), LHTestU64 },
    };
    LHTestBoundaries(TASK_BASIC_INFO_64, TASK_BASIC_INFO_64_COUNT, basic64Fields, 2);
}

static void LHTestVMFieldCoverage(void) {
    memset(LHTestOriginalData, 0x36, sizeof(LHTestOriginalData));
    for (size_t index = 0; index < sizeof(LHTestVMFields) / sizeof(LHTestVMFields[0]); index++) {
        uint64_t value = 32ULL * 1024 * 1024 + index * 16384 + 17;
        memcpy(LHTestOriginalData + LHTestVMFields[index].offset, &value, sizeof(value));
    }
    LHTestBoundaries(TASK_VM_INFO, TASK_VM_INFO_COUNT, LHTestVMFields,
                     sizeof(LHTestVMFields) / sizeof(LHTestVMFields[0]));
    LHTestBoundaries(TASK_VM_INFO_PURGEABLE, TASK_VM_INFO_COUNT, LHTestVMFields,
                     sizeof(LHTestVMFields) / sizeof(LHTestVMFields[0]));
}

static void LHTestHostCoherence(void) {
    vm_statistics_data_t narrow = { 0 };
    vm_statistics64_data_t wide = { 0 };
#define LH_TEST_SHARED_VM_FIELD(field) narrow.field = 1234567; wide.field = narrow.field
    LH_TEST_SHARED_VM_FIELD(free_count);
    LH_TEST_SHARED_VM_FIELD(active_count);
    LH_TEST_SHARED_VM_FIELD(inactive_count);
    LH_TEST_SHARED_VM_FIELD(wire_count);
    LH_TEST_SHARED_VM_FIELD(pageins);
    LH_TEST_SHARED_VM_FIELD(pageouts);
    LH_TEST_SHARED_VM_FIELD(faults);
    LH_TEST_SHARED_VM_FIELD(cow_faults);
    LH_TEST_SHARED_VM_FIELD(purgeable_count);
    LH_TEST_SHARED_VM_FIELD(purges);
    LH_TEST_SHARED_VM_FIELD(speculative_count);
#undef LH_TEST_SHARED_VM_FIELD
    LHMemoryShapeVMStatistics(&narrow);
    LHMemoryShapeVMStatistics64(&wide, HOST_VM_INFO64_COUNT);
#define LH_TEST_SHARED_VM_FIELD(field) assert(narrow.field == wide.field)
    LH_TEST_SHARED_VM_FIELD(free_count);
    LH_TEST_SHARED_VM_FIELD(active_count);
    LH_TEST_SHARED_VM_FIELD(inactive_count);
    LH_TEST_SHARED_VM_FIELD(wire_count);
    LH_TEST_SHARED_VM_FIELD(pageins);
    LH_TEST_SHARED_VM_FIELD(pageouts);
    LH_TEST_SHARED_VM_FIELD(faults);
    LH_TEST_SHARED_VM_FIELD(cow_faults);
    LH_TEST_SHARED_VM_FIELD(purgeable_count);
    LH_TEST_SHARED_VM_FIELD(purges);
    LH_TEST_SHARED_VM_FIELD(speculative_count);
#undef LH_TEST_SHARED_VM_FIELD
}

static void LHTestPassThrough(LHPolicyEngine *policy) {
    task_vm_info_data_t output;
    memset(LHTestOriginalData, 0x51, sizeof(LHTestOriginalData));
    LHTestReturnedCount = TASK_VM_INFO_COUNT;
    const task_flavor_t unsupported[] = { TASK_THREAD_TIMES_INFO, TASK_EVENTS_INFO, TASK_DYLD_INFO, TASK_POWER_INFO, 999 };
    for (size_t index = 0; index < sizeof(unsupported) / sizeof(unsupported[0]); index++) {
        mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
        assert(LHMemoryTaskInfoReplacement(mach_task_self(), unsupported[index], (task_info_t)&output, &count)
               == KERN_SUCCESS);
        assert(memcmp(&output, LHTestOriginalData, sizeof(output)) == 0);
    }
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    assert(LHMemoryTaskInfoReplacement(mach_task_self() + 1, TASK_VM_INFO, (task_info_t)&output, &count) == KERN_SUCCESS);
    assert(memcmp(&output, LHTestOriginalData, sizeof(output)) == 0);

    LHTestResult = KERN_INVALID_ARGUMENT;
    count = TASK_VM_INFO_COUNT;
    assert(LHMemoryTaskInfoReplacement(mach_task_self(), TASK_VM_INFO, (task_info_t)&output, &count) == LHTestResult);
    assert(count == LHTestReturnedCount && memcmp(&output, LHTestOriginalData, sizeof(output)) == 0);
    LHTestResult = KERN_SUCCESS;

    policy->appContext.scope.identifierLength = sizeof(policy->appContext.scope.identifier) + 1;
    assert(LHMemoryProcessQuantum() == 0);
    count = TASK_VM_INFO_COUNT;
    assert(LHMemoryTaskInfoReplacement(mach_task_self(), TASK_VM_INFO, (task_info_t)&output, &count) == KERN_SUCCESS);
    assert(memcmp(&output, LHTestOriginalData, sizeof(output)) == 0);
    policy->appContext.scope.identifierLength = 1;
    LHMemoryPolicy = 0;
    count = TASK_VM_INFO_COUNT;
    assert(LHMemoryTaskInfoReplacement(mach_task_self(), TASK_VM_INFO, (task_info_t)&output, &count) == KERN_SUCCESS);
    assert(memcmp(&output, LHTestOriginalData, sizeof(output)) == 0);
    LHMemoryPolicy = policy;

    count = TASK_VM_INFO_COUNT;
    assert(LHMemoryTaskInfoReplacement(mach_task_self(), TASK_VM_INFO, 0, &count) == KERN_SUCCESS);
    memset(&output, 0xa5, sizeof(output));
    task_vm_info_data_t untouched = output;
    assert(LHMemoryTaskInfoReplacement(mach_task_self(), TASK_VM_INFO, (task_info_t)&output, 0) == KERN_SUCCESS);
    assert(memcmp(&output, &untouched, sizeof(output)) == 0);
    LHMemoryTaskInfoOriginalImplementation = 0;
    assert(LHMemoryTaskInfoReplacement(mach_task_self(), TASK_VM_INFO, (task_info_t)&output, 0) == KERN_FAILURE);
}

int main(void) {
    assert(MACH_TASK_BASIC_INFO == 0x14 && TASK_VM_INFO == 0x16);
    LHPolicyEngine policy = {0};
    policy.appContext.scope.mode = LHScopeModePerAppInstall;
    policy.appContext.scope.identifierLength = 1;
    policy.appContext.scope.identifier[0] = 7;
    policy.config.buildSeed.bytes[0] = 9;
    LHHookBackendVTable vtable = {
        .hookFunction = LHTestFunctionHook, .hookImportedSymbol = LHTestImportedHook, .registerNoOp = LHTestNoOp,
    };
    LHHookBackend backend = { .vtable = &vtable };
    LHTestAcceptTaskHook = true;
    assert(LHMitigation_system_memory_counters_mach_bucketed_install(&backend, &policy));
    assert(LHTestTaskHooks == 1 && LHTestNoOps == 0);
    uint64_t baseline = LHMemoryProcessQuantum();
    assert(LHMemoryProcessQuantum() == baseline);
    bool seedChangesQuantum = false, scopeChangesQuantum = false;
    for (unsigned index = 0; index < 32; index++) {
        policy.config.buildSeed.bytes[0] = (uint8_t)index;
        seedChangesQuantum |= LHMemoryProcessQuantum() != baseline;
        policy.config.buildSeed.bytes[0] = 9;
        policy.appContext.scope.identifier[0] = (uint8_t)index;
        scopeChangesQuantum |= LHMemoryProcessQuantum() != baseline;
        policy.appContext.scope.identifier[0] = 7;
    }
    assert(seedChangesQuantum && scopeChangesQuantum);
    LHTestPrecision();
    LHTestCoherence();
    LHTestHostCoherence();
    LHTestVMFieldCoverage();
    LHTestPassThrough(&policy);
    LHTestAcceptTaskHook = false;
    assert(LHMitigation_system_memory_counters_mach_bucketed_install(&backend, &policy));
    assert(LHTestTaskHooks == 2 && LHTestNoOps == 1 && LHTestStateCalls == 0);
    puts("process memory check passed (ABI boundaries, scoped coherence, pass-through, import hook)");
    return 0;
}
