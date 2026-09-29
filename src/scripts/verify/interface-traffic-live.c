#include <assert.h>
#include <stdio.h>

#include "../../runtime/hooks/LHHookBackendTheos.c"
#include "../../mitigations/network/interface_inventory/InterfaceTrafficValues.c"
#include "../../mitigations/network/interface_inventory/InterfaceTrafficMitigation.c"
#include "../../mitigations/network/interface_inventory/InterfaceInventoryMitigation.c"

bool LHPolicyEngineLoadOrCreateState(const LHPolicyEngine *engine, const LHStateKey *key,
                                    uint8_t *output, size_t length, LHStateGenerateBytes generate,
                                    void *context, LHStateLoadResult *result) {
    (void)engine; (void)key; (void)output; (void)length;
    (void)generate; (void)context; (void)result;
    return false;
}

static struct ifaddrs *LHOriginalList;
static unsigned int LHChecked;

static const char *LHOriginalName(unsigned int index) {
    for (struct ifaddrs *entry = LHOriginalList; entry != 0; entry = entry->ifa_next) {
        if (entry->ifa_addr != 0 && entry->ifa_addr->sa_family == AF_LINK &&
            ((struct sockaddr_dl *)entry->ifa_addr)->sdl_index == index) {
            return entry->ifa_name;
        }
    }
    return 0;
}

static void LHCheckCounter(LHPolicyEngine *policy, const char *name, uint64_t observed,
                            bool wide, const LHInterfaceTrafficSnapshot *before,
                            const LHInterfaceTrafficSnapshot *after) {
    assert(name != 0);
    if (strncmp(name, "lo", 2) == 0) return;
    LHInterfaceTrafficValues first, last;
    assert(LHInterfaceTrafficCopyValues(policy, name, before, &first));
    assert(LHInterfaceTrafficCopyValues(policy, name, after, &last));
    assert(last.inboundBytes >= first.inboundBytes);
    if (wide) {
        assert(observed >= first.inboundBytes && observed <= last.inboundBytes);
    } else {
        assert((uint32_t)((uint32_t)observed - (uint32_t)first.inboundBytes) <=
               last.inboundBytes - first.inboundBytes);
    }
    LHChecked++;
}

static void LHCheckList(LHPolicyEngine *policy) {
    LHInterfaceTrafficSnapshot before, after;
    assert(LHInterfaceTrafficCopySnapshot(&before));
    struct ifaddrs *list = 0;
    assert(getifaddrs(&list) == 0);
    assert(LHInterfaceTrafficCopySnapshot(&after));
    for (struct ifaddrs *entry = list; entry != 0; entry = entry->ifa_next) {
        if (entry->ifa_addr != 0 && entry->ifa_addr->sa_family == AF_LINK && entry->ifa_data != 0) {
            const char *name = LHOriginalName(((struct sockaddr_dl *)entry->ifa_addr)->sdl_index);
            assert(name != 0);
            LHCheckCounter(policy, name, ((struct if_data *)entry->ifa_data)->ifi_ibytes,
                            false, &before, &after);
            if (LHInterfaceInventoryNameLooksSensitive(name)) {
                assert(strncmp(entry->ifa_name, "en", 2) == 0);
            }
        }
    }
    freeifaddrs(list);
}

static void LHCheckDump(LHPolicyEngine *policy, int query) {
    int mib[] = { CTL_NET, PF_ROUTE, 0, 0, query, 0 };
    size_t length = 0;
    assert(sysctl(mib, 6, 0, &length, 0, 0) == 0 && length > 0);
    uint8_t *bytes = malloc(length);
    assert(bytes != 0);
    LHInterfaceTrafficSnapshot before, after;
    assert(LHInterfaceTrafficCopySnapshot(&before));
    assert(sysctl(mib, 6, bytes, &length, 0, 0) == 0);
    assert(LHInterfaceTrafficCopySnapshot(&after));
    for (size_t offset = 0; offset < length;) {
        LHInterfaceTrafficMessage message;
        assert(LHInterfaceTrafficParseMessage(bytes + offset, length - offset, query, &message));
        if (message.data32 != 0 || message.data64 != 0) {
            const char *name = LHOriginalName(message.index);
            LHCheckCounter(policy, name, message.data32 != 0 ? message.data32->ifi_ibytes : message.data64->ifi_ibytes,
                            message.data64 != 0, &before, &after);
        }
        offset += message.length;
    }
    free(bytes);
}

int main(void) {
    assert(getifaddrs(&LHOriginalList) == 0);
    LHPolicyEngine policy = { 0 };
    assert(LHSeedParseUUID("123e4567-e89b-12d3-a456-426614174000", &policy.config.buildSeed));
    assert(LHScopeInitPerApp(&policy.appContext.scope, "example.traffic.live"));
    LHHookBackend backend = LHHookBackendCreateTheos();
    assert(LHMitigation_network_interface_inventory_composite_common_install(&backend, &policy));
    for (unsigned int iteration = 0; iteration < 3; iteration++) {
        LHCheckList(&policy);
        LHCheckDump(&policy, NET_RT_IFLIST);
        LHCheckDump(&policy, NET_RT_IFLIST2);
    }
    assert(LHChecked > 0);
    freeifaddrs(LHOriginalList);
    printf("live interface traffic check passed (%u counter reads via actual backend)\n", LHChecked);
    return 0;
}
