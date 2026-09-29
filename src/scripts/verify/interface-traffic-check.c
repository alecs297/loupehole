#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <sys/sysctl.h>

#include "../../mitigations/network/interface_inventory/InterfaceTrafficMitigation.h"

static struct timeval LHTestNow = { 1800000000, 500000 };
static struct timeval LHTestBoot = { 1799000000, 0 };
static bool LHTestClockFailure;

static int LHTestBootQuery(const char *name, void *output, size_t *length, void *input, size_t inputLength) {
    (void)input; (void)inputLength;
    assert(strcmp(name, "kern.boottime") == 0);
    if (LHTestClockFailure) {
        return -1;
    }
    assert(*length == sizeof(LHTestBoot));
    memcpy(output, &LHTestBoot, sizeof(LHTestBoot));
    return 0;
}

static int LHTestGetTime(struct timeval *now, void *zone) {
    (void)zone;
    *now = LHTestNow;
    return 0;
}

#define sysctlbyname LHTestBootQuery
#define gettimeofday LHTestGetTime
#include "../../mitigations/network/interface_inventory/InterfaceTrafficValues.c"
#include "../../mitigations/network/interface_inventory/InterfaceTrafficMitigation.c"
#include "../../mitigations/network/interface_inventory/InterfaceInventoryMitigation.c"
#undef sysctlbyname
#undef gettimeofday

bool LHPolicyEngineLoadOrCreateState(const LHPolicyEngine *engine, const LHStateKey *key,
                                    uint8_t *output, size_t length, LHStateGenerateBytes generate,
                                    void *context, LHStateLoadResult *result) {
    (void)engine; (void)key; (void)output; (void)length;
    (void)generate; (void)context; (void)result;
    return false;
}

static size_t LHTestAppendInterface(uint8_t *output, int query, const char *name, unsigned int index) {
    size_t nameLength = strlen(name);
    size_t linkLength = offsetof(struct sockaddr_dl, sdl_data) + nameLength + 6;
    size_t headerLength = query == NET_RT_IFLIST ? sizeof(struct if_msghdr) : sizeof(struct if_msghdr2);
    size_t length = headerLength + ((linkLength + 3U) & ~3U);
    memset(output, 0, length);
    struct sockaddr_dl *link = (struct sockaddr_dl *)(output + headerLength);
    link->sdl_len = (uint8_t)linkLength;
    link->sdl_family = AF_LINK;
    link->sdl_index = (uint16_t)index;
    link->sdl_nlen = (uint8_t)nameLength;
    link->sdl_alen = 6;
    memcpy(link->sdl_data, name, nameLength);
    memset(LLADDR(link), 0xa4, 6);
    if (query == NET_RT_IFLIST) {
        struct if_msghdr *header = (struct if_msghdr *)output;
        header->ifm_msglen = (uint16_t)length;
        header->ifm_version = RTM_VERSION;
        header->ifm_type = RTM_IFINFO;
        header->ifm_addrs = RTA_IFP;
        header->ifm_index = (uint16_t)index;
        header->ifm_flags = IFF_UP | IFF_RUNNING;
        header->ifm_data.ifi_ibytes = 123;
        header->ifm_data.ifi_obytes = 456;
        header->ifm_data.ifi_baudrate = 1234;
        header->ifm_data.ifi_mtu = 1500;
    } else {
        struct if_msghdr2 *header = (struct if_msghdr2 *)output;
        header->ifm_msglen = (uint16_t)length;
        header->ifm_version = RTM_VERSION;
        header->ifm_type = RTM_IFINFO2;
        header->ifm_addrs = RTA_IFP;
        header->ifm_index = (uint16_t)index;
        header->ifm_flags = IFF_UP | IFF_RUNNING;
        header->ifm_data.ifi_ibytes = 123;
        header->ifm_data.ifi_obytes = 456;
        header->ifm_data.ifi_baudrate = 1234;
        header->ifm_data.ifi_mtu = 1500;
    }
    return length;
}

static size_t LHTestAppendAddress(uint8_t *output, unsigned int index) {
    size_t length = sizeof(struct ifa_msghdr) + 8 + 2 * sizeof(struct sockaddr_in);
    memset(output, 0, length);
    struct ifa_msghdr *header = (struct ifa_msghdr *)output;
    header->ifam_msglen = (uint16_t)length;
    header->ifam_version = RTM_VERSION;
    header->ifam_type = RTM_NEWADDR;
    header->ifam_index = (uint16_t)index;
    header->ifam_flags = IFF_UP | IFF_RUNNING;
    header->ifam_addrs = RTA_NETMASK | RTA_IFA | RTA_BRD;
    uint8_t *addresses = output + sizeof(*header);
    struct sockaddr_in mask = { 0 };
    mask.sin_len = 8;
    mask.sin_addr.s_addr = htonl(0xffff0000);
    memcpy(addresses, &mask, 8);
    struct sockaddr_in address = { 0 };
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(0x0a0b0c0d);
    memcpy(addresses + 8, &address, sizeof(address));
    address.sin_addr.s_addr = htonl(0x0a0bffff);
    memcpy(addresses + 8 + sizeof(address), &address, sizeof(address));
    return length;
}

static const char *const LHTestNames[] = { "en0", "pdp_ip0", "pdp_ip1", "utun7", "lo0" };

static void LHTestDumps(LHPolicyEngine *policy, const LHInterfaceTrafficSnapshot *snapshot) {
    uint8_t original32[2048], original64[2048], shaped32[2048], shaped64[2048];
    size_t offsets32[5], offsets64[5], length32 = 0, length64 = 0;
    for (size_t index = 0; index < 5; index++) {
        offsets32[index] = length32;
        offsets64[index] = length64;
        length32 += LHTestAppendInterface(original32 + length32, NET_RT_IFLIST, LHTestNames[index], (unsigned int)index + 1);
        length64 += LHTestAppendInterface(original64 + length64, NET_RT_IFLIST2, LHTestNames[index], (unsigned int)index + 1);
        if (index == 0 || index == 3) {
            length32 += LHTestAppendAddress(original32 + length32, (unsigned int)index + 1);
            length64 += LHTestAppendAddress(original64 + length64, (unsigned int)index + 1);
        }
    }
    memcpy(shaped32, original32, length32);
    memcpy(shaped64, original64, length64);
    assert(LHInterfaceTrafficShapeBuffer(policy, shaped32, length32, NET_RT_IFLIST, snapshot));
    assert(LHInterfaceTrafficShapeBuffer(policy, shaped64, length64, NET_RT_IFLIST2, snapshot));
    uint64_t cellularIn = 0, expectedCellularIn = 0;
    for (size_t index = 0; index < 5; index++) {
        struct if_msghdr *legacy = (struct if_msghdr *)(shaped32 + offsets32[index]);
        struct if_msghdr2 *wide = (struct if_msghdr2 *)(shaped64 + offsets64[index]);
        assert(legacy->ifm_data.ifi_mtu == 1500 && wide->ifm_data.ifi_mtu == 1500);
        assert(legacy->ifm_data.ifi_ibytes == (uint32_t)wide->ifm_data.ifi_ibytes);
        assert(legacy->ifm_data.ifi_obytes == (uint32_t)wide->ifm_data.ifi_obytes);
        assert(legacy->ifm_data.ifi_ipackets == (uint32_t)wide->ifm_data.ifi_ipackets);
        if (index == 4) {
            assert(memcmp(shaped32 + offsets32[index], original32 + offsets32[index], legacy->ifm_msglen) == 0);
            assert(memcmp(shaped64 + offsets64[index], original64 + offsets64[index], wide->ifm_msglen) == 0);
            continue;
        }
        LHInterfaceTrafficValues expected;
        assert(LHInterfaceTrafficCopyValues(policy, LHTestNames[index], snapshot, &expected));
        assert(wide->ifm_data.ifi_ibytes == expected.inboundBytes);
        assert(wide->ifm_data.ifi_lastchange.tv_sec == snapshot->bootSeconds);
        struct sockaddr_dl *link = (struct sockaddr_dl *)(legacy + 1);
        if (index == 3) {
            assert((legacy->ifm_flags & (IFF_UP | IFF_RUNNING)) == 0);
            assert(link->sdl_nlen == 3 && memcmp(link->sdl_data, "en", 2) == 0);
        }
        if (strncmp(LHTestNames[index], "pdp_ip", 6) == 0) {
            cellularIn += wide->ifm_data.ifi_ibytes;
            expectedCellularIn += expected.inboundBytes;
        }
        if (index == 0 || index == 3) {
            LHInterfaceTrafficMessage address;
            assert(LHInterfaceTrafficParseMessage(shaped32 + offsets32[index] + legacy->ifm_msglen,
                                                 length32 - offsets32[index] - legacy->ifm_msglen,
                                                 NET_RT_IFLIST, &address));
            assert(*address.flags == (IFF_UP | IFF_RUNNING));
            struct sockaddr_in *ip = (struct sockaddr_in *)address.addresses[RTAX_IFA];
            struct sockaddr_in *mask = (struct sockaddr_in *)address.addresses[RTAX_NETMASK];
            assert((ntohl(ip->sin_addr.s_addr) & 0xffffff00U) == 0xc0a80100U);
            assert(ntohl(mask->sin_addr.s_addr) == 0xffffff00U && mask->sin_len == 8);
            assert(ntohl(((struct sockaddr_in *)address.addresses[RTAX_BRD])->sin_addr.s_addr) == 0xc0a801ffU);
        }
    }
    assert(cellularIn == expectedCellularIn && cellularIn > 0);

    // A malformed trailing message must preserve every earlier byte, even after it could be shaped.
    memcpy(shaped32, original32, length32);
    shaped32[length32] = 0;
    uint8_t saved[2048];
    memcpy(saved, shaped32, length32 + 1);
    assert(!LHInterfaceTrafficShapeBuffer(policy, shaped32, length32 + 1, NET_RT_IFLIST, snapshot));
    assert(memcmp(saved, shaped32, length32 + 1) == 0);
    for (size_t length = 1; length < ((struct if_msghdr *)original32)->ifm_msglen; length++) {
        memcpy(shaped32, original32, length);
        assert(!LHInterfaceTrafficShapeBuffer(policy, shaped32, length, NET_RT_IFLIST, snapshot));
        assert(memcmp(shaped32, original32, length) == 0);
    }
}

static void LHTestGrowth(LHPolicyEngine *policy) {
    LHInterfaceTrafficSnapshot before = { 0, LHTestBoot.tv_sec }, after = before;
    LHInterfaceTrafficValues first, second, other;
    assert(LHInterfaceTrafficCopyValues(policy, "en0", &before, &first));
    after.elapsedMicroseconds = 500000;
    assert(LHInterfaceTrafficCopyValues(policy, "en0", &after, &second));
    assert(second.inboundBytes > first.inboundBytes && second.outboundBytes > first.outboundBytes);
    assert(second.inboundPackets >= first.inboundPackets);
    LHPolicyEngine otherPolicy = *policy;
    assert(LHScopeInitPerApp(&otherPolicy.appContext.scope, "example.other"));
    assert(LHInterfaceTrafficCopyValues(&otherPolicy, "en0", &before, &other));
    assert(other.inboundBytes != first.inboundBytes || other.outboundBytes != first.outboundBytes);
    assert(LHInterfaceTrafficCopyValues(policy, "pdp_ip0", &before, &other));
    assert(other.inboundBytes != first.inboundBytes || other.outboundBytes != first.outboundBytes);

    uint64_t low = 0, high = 3ULL * 365 * 24 * 3600 * 1000000;
    while (low + 1 < high) {
        after.elapsedMicroseconds = low + (high - low) / 2;
        assert(LHInterfaceTrafficCopyValues(policy, "en0", &after, &second));
        if (second.inboundBytes > UINT32_MAX) {
            high = after.elapsedMicroseconds;
        } else {
            low = after.elapsedMicroseconds;
        }
    }
    before.elapsedMicroseconds = high - 1000000;
    after.elapsedMicroseconds = high + 1000000;
    assert(LHInterfaceTrafficCopyValues(policy, "en0", &before, &first));
    assert(LHInterfaceTrafficCopyValues(policy, "en0", &after, &second));
    assert(first.inboundBytes <= UINT32_MAX && second.inboundBytes > UINT32_MAX);
    struct if_data legacyFirst = { 0 }, legacySecond = { 0 };
    struct if_data64 wide = { 0 };
    LHInterfaceTrafficApply32(&legacyFirst, "en0", &before, &first);
    LHInterfaceTrafficApply32(&legacySecond, "en0", &after, &second);
    LHInterfaceTrafficApply64(&wide, "en0", &after, &second);
    assert(legacySecond.ifi_ibytes < legacyFirst.ifi_ibytes);
    assert((uint32_t)(legacySecond.ifi_ibytes - legacyFirst.ifi_ibytes) == second.inboundBytes - first.inboundBytes);
    assert(wide.ifi_ibytes == second.inboundBytes && wide.ifi_ibytes > UINT32_MAX);
    after.elapsedMicroseconds += 500000;
    assert(LHInterfaceTrafficCopyValues(policy, "en0", &after, &other));
    assert(other.inboundBytes > second.inboundBytes);
    LHTestDumps(policy, &after);
    assert(!LHInterfaceTrafficCopyValues(0, "en0", &after, &other));
}

static struct ifaddrs LHTestList[3];
static struct sockaddr_dl LHTestLinks[3];
static struct if_data LHTestData[3];
static char LHTestListNames[3][IFNAMSIZ];
static int LHTestListResult;

static int LHTestGetIfAddrs(struct ifaddrs **result) {
    assert(LHTrafficOriginalListDepth != 0);
    errno = LHTestListResult == 0 ? EBUSY : ENETDOWN;
    if (LHTestListResult == 0) {
        *result = LHTestList;
    }
    return LHTestListResult;
}

static void LHTestListReads(LHPolicyEngine *policy) {
    LHInterfaceInventoryGetIfAddrsOriginalImplementation = LHTestGetIfAddrs;
    for (size_t index = 0; index < 3; index++) {
        strcpy(LHTestListNames[index], LHTestNames[index]);
        LHTestList[index].ifa_name = LHTestListNames[index];
        LHTestList[index].ifa_addr = (struct sockaddr *)&LHTestLinks[index];
        LHTestList[index].ifa_data = &LHTestData[index];
        LHTestList[index].ifa_next = index == 2 ? 0 : &LHTestList[index + 1];
        LHTestLinks[index].sdl_family = AF_LINK;
        LHTestData[index].ifi_ibytes = 7;
    }
    struct ifaddrs *list = 0;
    assert(LHInterfaceInventoryGetIfAddrsReplacement(&list) == 0 && list == LHTestList && errno == EBUSY);
    assert(LHTrafficOriginalListDepth == 0);
    LHInterfaceTrafficSnapshot snapshot;
    assert(LHInterfaceTrafficCopySnapshot(&snapshot));
    uint64_t total = 0;
    for (size_t index = 0; index < 3; index++) {
        LHInterfaceTrafficValues expected;
        assert(LHInterfaceTrafficCopyValues(policy, LHTestListNames[index], &snapshot, &expected));
        assert(LHTestData[index].ifi_ibytes == (uint32_t)expected.inboundBytes);
        if (strncmp(LHTestListNames[index], "pdp_ip", 6) == 0) {
            total += LHTestData[index].ifi_ibytes;
        }
    }
    assert(total == (uint64_t)LHTestData[1].ifi_ibytes + LHTestData[2].ifi_ibytes);
    LHTestListResult = -1;
    assert(LHInterfaceInventoryGetIfAddrsReplacement(&list) == -1 && errno == ENETDOWN);
    assert(LHTrafficOriginalListDepth == 0);
    LHTestListResult = 0;
    LHTestClockFailure = true;
    LHTestData[0].ifi_ibytes = 9;
    assert(LHInterfaceInventoryGetIfAddrsReplacement(&list) == 0 && LHTestData[0].ifi_ibytes == 9);
    LHTestClockFailure = false;
}

static uint8_t LHTestRawBytes[512];
static size_t LHTestRawLength;
static size_t LHTestReturnedLength;
static int LHTestRawResult;

static int LHTestSysctlOriginal(int *name, u_int count, void *output, size_t *length,
                                void *input, size_t inputLength) {
    (void)name; (void)count; (void)input; (void)inputLength;
    if (output != 0 && length != 0) {
        size_t copied = *length < LHTestRawLength ? *length : LHTestRawLength;
        memcpy(output, LHTestRawBytes, copied);
    }
    if (length != 0) *length = LHTestReturnedLength;
    errno = LHTestRawResult == 0 ? EBUSY : ENOMEM;
    return LHTestRawResult;
}

static int LHTestNestedSysctl(int *name, u_int count, void *output, size_t *length,
                             void *input, size_t inputLength) {
    return LHInterfaceTrafficSysctlRead(LHTestSysctlOriginal, name, count, output,
                                        length, input, inputLength);
}

static void LHTestRawReads(LHPolicyEngine *policy) {
    LHTrafficPolicy = policy;
    LHTestRawLength = LHTestAppendInterface(LHTestRawBytes, NET_RT_IFLIST2, "utun7", 7);
    LHTestReturnedLength = LHTestRawLength;
    int mib[] = { CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_IFLIST2, 7 };
    uint8_t output[512];
    size_t length = sizeof(output);
    assert(LHInterfaceTrafficSysctlRead(LHTestNestedSysctl, mib, 6, output, &length, 0, 0) == 0);
    assert(length == LHTestRawLength && errno == EBUSY && LHTrafficRawDepth == 0);
    LHInterfaceTrafficSnapshot snapshot;
    LHInterfaceTrafficValues expected;
    assert(LHInterfaceTrafficCopySnapshot(&snapshot));
    assert(LHInterfaceTrafficCopyValues(policy, "utun7", &snapshot, &expected));
    assert(((struct if_msghdr2 *)output)->ifm_data.ifi_ibytes == expected.inboundBytes);
    struct sockaddr_dl *link = (struct sockaddr_dl *)(output + sizeof(struct if_msghdr2));
    assert(link->sdl_nlen == 3 && memcmp(link->sdl_data, "en", 2) == 0);

    length = 0;
    assert(LHInterfaceTrafficSysctlRead(LHTestNestedSysctl, mib, 6, 0, &length, 0, 0) == 0);
    assert(length == LHTestRawLength && errno == EBUSY && LHTrafficRawDepth == 0);
    for (unsigned int scenario = 0; scenario < 6; scenario++) {
        length = sizeof(output);
        LHTestRawResult = scenario == 0 ? -1 : 0;
        LHTestClockFailure = scenario == 1;
        LHTestReturnedLength = scenario == 2 ? sizeof(output) + 1 : LHTestRawLength;
        if (scenario == 3) LHInterfaceTrafficBeginOriginalList();
        if (scenario == 4) mib[4] = NET_RT_DUMP;
        void *input = scenario == 5 ? output : 0;
        int result = LHInterfaceTrafficSysctlRead(LHTestNestedSysctl, mib, 6, output, &length, input, 0);
        assert(result == LHTestRawResult && errno == (result == 0 ? EBUSY : ENOMEM));
        assert(memcmp(output, LHTestRawBytes, LHTestRawLength) == 0 && LHTrafficRawDepth == 0);
        if (scenario == 3) LHInterfaceTrafficEndOriginalList();
        mib[4] = NET_RT_IFLIST2;
    }
    LHTestRawResult = 0;
    LHTestClockFailure = false;
}

int main(void) {
    LHPolicyEngine policy = { 0 };
    assert(LHSeedParseUUID("123e4567-e89b-12d3-a456-426614174000", &policy.config.buildSeed));
    assert(LHScopeInitPerApp(&policy.appContext.scope, "example.traffic"));
    LHInterfaceInventoryPolicy = &policy;
    LHInterfaceTrafficSnapshot snapshot;
    assert(LHInterfaceTrafficCopySnapshot(&snapshot));
    assert(snapshot.elapsedMicroseconds == 1000000500000ULL);
    LHTestDumps(&policy, &snapshot);
    LHTestGrowth(&policy);
    LHTestListReads(&policy);
    LHTestRawReads(&policy);
    puts("interface traffic check passed");
    return 0;
}
