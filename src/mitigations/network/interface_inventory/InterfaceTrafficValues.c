#include "InterfaceTrafficValues.h"
#include "LHGeneratedPolicySeeds.h"
#include "LHMitigationValues.h"

#include <stdio.h>
#include <string.h>
#include <sys/sysctl.h>

LH_POLICY_SEED(network_interface_counter_profile)

bool LHInterfaceTrafficCopySnapshot(LHInterfaceTrafficSnapshot *snapshot) {
    struct timeval boot = { 0 };
    struct timeval now = { 0 };
    size_t length = sizeof(boot);
    if (snapshot == 0 || sysctlbyname("kern.boottime", &boot, &length, 0, 0) != 0 ||
        length != sizeof(boot) || gettimeofday(&now, 0) != 0 || boot.tv_sec <= 0 ||
        boot.tv_usec < 0 || boot.tv_usec >= 1000000 || now.tv_sec < boot.tv_sec) {
        return false;
    }

    uint64_t seconds = (uint64_t)(now.tv_sec - boot.tv_sec);
    if (seconds > (UINT64_MAX - 1000000ULL) / 1000000ULL) {
        return false;
    }
    uint64_t elapsed = seconds * 1000000ULL + (uint64_t)now.tv_usec;
    if (elapsed < (uint64_t)boot.tv_usec) {
        return false;
    }
    snapshot->elapsedMicroseconds = elapsed - (uint64_t)boot.tv_usec;
    snapshot->bootSeconds = boot.tv_sec;
    return true;
}

static bool LHInterfaceTrafficDerive(LHPolicyEngine *policy, const char *name,
                                     const char *field, uint64_t limit, uint64_t *value) {
    if (policy == 0 || name == 0 || name[0] == '\0' || field == 0 || value == 0) {
        return false;
    }
    char context[96];
    int length = snprintf(context, sizeof(context), "%s:%s", name, field);
    if (length < 0 || (size_t)length >= sizeof(context)) {
        return false;
    }
    return LHMitigationDeriveBoundedU64(&policy->config.buildSeed,
                                       &LHGeneratedPolicySeed_network_interface_counter_profile,
                                       &policy->appContext.scope,
                                       (const uint8_t *)context, (size_t)length, limit, value);
}

static bool LHInterfaceTrafficBytes(LHPolicyEngine *policy, const char *name,
                                    const char *field, uint64_t elapsed, uint64_t *bytes) {
    uint64_t base = 0, rate = 0, step = 0;
    if (!LHInterfaceTrafficDerive(policy, name, field, 240ULL * 1024ULL * 1024ULL, &base) ||
        !LHInterfaceTrafficDerive(policy, name, field, 449ULL, &rate) ||
        !LHInterfaceTrafficDerive(policy, name, field, 4096ULL, &step)) {
        return false;
    }
    base += 16ULL * 1024ULL * 1024ULL;
    rate += 64ULL;
    step += 1ULL;
    uint64_t seconds = elapsed / 1000000ULL;
    uint64_t growth = 0, steps = seconds / 300ULL;
    if (seconds > (UINT64_MAX - base) / rate) {
        return false;
    }
    growth = base + seconds * rate;
    uint64_t fractional = (elapsed % 1000000ULL) * rate / 1000000ULL;
    if (fractional > UINT64_MAX - growth) {
        return false;
    }
    growth += fractional;
    if (steps > (UINT64_MAX - growth) / step) {
        return false;
    }
    *bytes = growth + steps * step;
    return true;
}

bool LHInterfaceTrafficCopyValues(LHPolicyEngine *policy, const char *name,
                                  const LHInterfaceTrafficSnapshot *snapshot,
                                  LHInterfaceTrafficValues *values) {
    LHInterfaceTrafficValues result = { 0 };
    uint64_t inputPacketSize = 0, outputPacketSize = 0;
    uint64_t inputErrors = 0, outputErrors = 0, drops = 0, unsupported = 0;
    if (snapshot == 0 || values == 0 ||
        !LHInterfaceTrafficBytes(policy, name, "ibytes", snapshot->elapsedMicroseconds, &result.inboundBytes) ||
        !LHInterfaceTrafficBytes(policy, name, "obytes", snapshot->elapsedMicroseconds, &result.outboundBytes) ||
        !LHInterfaceTrafficDerive(policy, name, "ipackets", 640, &inputPacketSize) ||
        !LHInterfaceTrafficDerive(policy, name, "opackets", 640, &outputPacketSize) ||
        !LHInterfaceTrafficDerive(policy, name, "ierrors", 3, &inputErrors) ||
        !LHInterfaceTrafficDerive(policy, name, "oerrors", 3, &outputErrors) ||
        !LHInterfaceTrafficDerive(policy, name, "iqdrops", 3, &drops) ||
        !LHInterfaceTrafficDerive(policy, name, "noproto", 3, &unsupported)) {
        return false;
    }
    result.inboundPackets = result.inboundBytes / (720ULL + inputPacketSize);
    result.outboundPackets = result.outboundBytes / (720ULL + outputPacketSize);
    result.inboundErrors = (uint32_t)inputErrors;
    result.outboundErrors = (uint32_t)outputErrors;
    result.inputDrops = (uint32_t)drops;
    result.unsupportedPackets = (uint32_t)unsupported;
    *values = result;
    return true;
}

static uint64_t LHInterfaceTrafficBaudRate(const char *name, uint64_t original) {
    if (original == 0) {
        return 0;
    }
    return strncmp(name, "en", 2) == 0 ? 1000000000ULL : 100000000ULL;
}

void LHInterfaceTrafficApply32(struct if_data *data, const char *name,
                               const LHInterfaceTrafficSnapshot *snapshot,
                               const LHInterfaceTrafficValues *values) {
    data->ifi_ibytes = (uint32_t)values->inboundBytes;
    data->ifi_obytes = (uint32_t)values->outboundBytes;
    data->ifi_ipackets = (uint32_t)values->inboundPackets;
    data->ifi_opackets = (uint32_t)values->outboundPackets;
    data->ifi_imcasts = (uint32_t)(values->inboundPackets / 64ULL);
    data->ifi_omcasts = (uint32_t)(values->outboundPackets / 64ULL);
    data->ifi_ierrors = values->inboundErrors;
    data->ifi_oerrors = values->outboundErrors;
    data->ifi_iqdrops = values->inputDrops;
    data->ifi_noproto = values->unsupportedPackets;
    data->ifi_collisions = 0;
    data->ifi_recvtiming = 0;
    data->ifi_xmittiming = 0;
    data->ifi_baudrate = (uint32_t)LHInterfaceTrafficBaudRate(name, data->ifi_baudrate);
    data->ifi_lastchange.tv_sec = (int32_t)snapshot->bootSeconds;
    data->ifi_lastchange.tv_usec = 0;
}

void LHInterfaceTrafficApply64(struct if_data64 *data, const char *name,
                               const LHInterfaceTrafficSnapshot *snapshot,
                               const LHInterfaceTrafficValues *values) {
    data->ifi_ibytes = values->inboundBytes;
    data->ifi_obytes = values->outboundBytes;
    data->ifi_ipackets = values->inboundPackets;
    data->ifi_opackets = values->outboundPackets;
    data->ifi_imcasts = values->inboundPackets / 64ULL;
    data->ifi_omcasts = values->outboundPackets / 64ULL;
    data->ifi_ierrors = values->inboundErrors;
    data->ifi_oerrors = values->outboundErrors;
    data->ifi_iqdrops = values->inputDrops;
    data->ifi_noproto = values->unsupportedPackets;
    data->ifi_collisions = 0;
    data->ifi_recvtiming = 0;
    data->ifi_xmittiming = 0;
    data->ifi_baudrate = LHInterfaceTrafficBaudRate(name, data->ifi_baudrate);
    data->ifi_lastchange.tv_sec = (int32_t)snapshot->bootSeconds;
    data->ifi_lastchange.tv_usec = 0;
}
