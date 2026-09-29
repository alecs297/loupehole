#include <net/route.h>
#include <stdio.h>
#include <stdlib.h>

#include "network/interface_inventory/RoutingTableMitigation.c"

#define CHECK(condition) do { \
    if (!(condition)) { \
        fprintf(stderr, "%s:%d: %s\n", __FILE__, __LINE__, #condition); \
        exit(1); \
    } \
    LHFixtureAssertions++; \
} while (0)

static unsigned int LHFixtureAssertions;
static uint8_t LHFixtureSource[4096];
static size_t LHFixtureSourceLength;
static int LHFixtureResult;
static int LHFixtureErrno;
static bool LHFixtureReportOversizedSuccess;
static unsigned int LHFixtureOriginalSymbol;
static unsigned int LHFixtureNameCalls;
static const char *LHFixtureName = "en0";
static void *LHFixtureNewValue;
static size_t LHFixtureNewLength;
static unsigned int LHFixtureHookCalls;

bool LHPolicyEngineLoadOrCreateState(const LHPolicyEngine *engine, const LHStateKey *key,
                                     uint8_t *output, size_t outputLength,
                                     LHStateGenerateBytes generate, void *context,
                                     LHStateLoadResult *result) {
    (void)engine;
    (void)key;
    (void)output;
    (void)outputLength;
    (void)generate;
    (void)context;
    (void)result;
    return false;
}

static char *LHFixtureResolveName(unsigned int index, char *name) {
    LHFixtureNameCalls++;
    errno = ENXIO;
    if (index != 7 || LHFixtureName == 0) {
        return 0;
    }
    CHECK(strlen(LHFixtureName) < IFNAMSIZ);
    strcpy(name, LHFixtureName);
    return name;
}

static int LHFixtureOriginal(int *name, unsigned int count, void *oldValue,
                              size_t *oldLength, void *newValue, size_t newLength) {
    (void)name;
    (void)count;
    LHFixtureNewValue = newValue;
    LHFixtureNewLength = newLength;
    if (oldLength == 0) {
        errno = EFAULT;
        return -1;
    }
    size_t capacity = *oldLength;
    if (oldValue != 0) {
        memcpy(oldValue, LHFixtureSource, capacity < LHFixtureSourceLength ? capacity : LHFixtureSourceLength);
    }
    *oldLength = LHFixtureSourceLength;
    if (oldValue != 0 && capacity < LHFixtureSourceLength && !LHFixtureReportOversizedSuccess) {
        errno = ENOMEM;
        return -1;
    }
    errno = LHFixtureErrno;
    return LHFixtureResult;
}

static int LHFixturePublicOriginal(int *name, unsigned int count, void *oldValue,
                                   size_t *oldLength, void *newValue, size_t newLength) {
    LHFixtureOriginalSymbol = 1;
    return LHFixtureOriginal(name, count, oldValue, oldLength, newValue, newLength);
}

static int LHFixturePrivateOriginal(int *name, unsigned int count, void *oldValue,
                                    size_t *oldLength, void *newValue, size_t newLength) {
    LHFixtureOriginalSymbol = 2;
    return LHFixtureOriginal(name, count, oldValue, oldLength, newValue, newLength);
}

static int LHFixtureNestedOriginal(int *name, unsigned int count, void *oldValue,
                                   size_t *oldLength, void *newValue, size_t newLength) {
    return LHRoutePrivateSysctlReplacement(name, count, oldValue, oldLength, newValue, newLength);
}

static bool LHFixtureHookImportedSymbol(LHHookBackend *backend, const char *symbol,
                                        void *replacement, void **original) {
    (void)backend;
    LHFixtureHookCalls++;
    if (strcmp(symbol, "sysctl") == 0) {
        CHECK(replacement == (void *)LHRouteSysctlReplacement);
        *original = (void *)LHFixturePublicOriginal;
    } else {
        CHECK(strcmp(symbol, "__sysctl") == 0);
        CHECK(replacement == (void *)LHRoutePrivateSysctlReplacement);
        *original = (void *)LHFixturePrivateOriginal;
    }
    return true;
}

static size_t LHFixtureAppend(uint8_t *bytes, size_t offset, const void *address, size_t length) {
    size_t step = length == 0 ? 4 : (length + 3U) & ~(size_t)3U;
    memset(bytes + offset, 0, step);
    if (length > 0) {
        memcpy(bytes + offset, address, length);
    }
    return offset + step;
}

static size_t LHFixtureBuildRoute(uint8_t *bytes, int operation, int family,
                                 bool includeLink, bool includeLocal) {
    struct rt_msghdr header = { 0 };
    header.rtm_version = RTM_VERSION;
    header.rtm_type = operation == NET_RT_DUMP2 ? RTM_GET2 : RTM_GET;
    header.rtm_index = 7;
    header.rtm_flags = RTF_UP | RTF_GATEWAY | RTF_STATIC;
    header.rtm_addrs = RTA_DST | RTA_GATEWAY | RTA_NETMASK;
    if (includeLink) {
        header.rtm_addrs |= RTA_IFP;
    }
    if (includeLocal) {
        header.rtm_addrs |= RTA_IFA;
    }
    size_t offset = sizeof(header);
    if (family == AF_INET) {
        struct sockaddr_in address = { .sin_len = sizeof(address), .sin_family = AF_INET };
        offset = LHFixtureAppend(bytes, offset, &address, sizeof(address));
        address.sin_addr.s_addr = htonl(0x0A110801U);
        offset = LHFixtureAppend(bytes, offset, &address, sizeof(address));
    } else {
        struct sockaddr_in6 address = { .sin6_len = sizeof(address), .sin6_family = AF_INET6 };
        offset = LHFixtureAppend(bytes, offset, &address, sizeof(address));
        CHECK(inet_pton(AF_INET6, "fe80:7::a", &address.sin6_addr) == 1);
        offset = LHFixtureAppend(bytes, offset, &address, sizeof(address));
    }
    /* A default route has a zero-length, four-byte mask slot on Darwin. */
    offset = LHFixtureAppend(bytes, offset, 0, 0);
    if (includeLink) {
        uint8_t link[40] = { 0 };
        size_t nameLength = strlen(LHFixtureName);
        size_t dataOffset = offsetof(struct sockaddr_dl, sdl_data);
        link[0] = (uint8_t)(dataOffset + nameLength + 6 + 2);
        link[1] = AF_LINK;
        uint16_t index = 7;
        memcpy(link + offsetof(struct sockaddr_dl, sdl_index), &index, sizeof(index));
        link[offsetof(struct sockaddr_dl, sdl_nlen)] = (uint8_t)nameLength;
        link[offsetof(struct sockaddr_dl, sdl_alen)] = 6;
        link[offsetof(struct sockaddr_dl, sdl_slen)] = 2;
        memcpy(link + dataOffset, LHFixtureName, nameLength);
        memset(link + dataOffset + nameLength, 0xab, 6);
        link[dataOffset + nameLength + 6] = 0x55;
        link[dataOffset + nameLength + 7] = 0xaa;
        offset = LHFixtureAppend(bytes, offset, link, link[0]);
    }
    if (includeLocal) {
        if (family == AF_INET) {
            struct sockaddr_in address = { .sin_len = sizeof(address), .sin_family = AF_INET };
            address.sin_addr.s_addr = htonl(0x0A110832U);
            offset = LHFixtureAppend(bytes, offset, &address, sizeof(address));
        } else {
            struct sockaddr_in6 address = { .sin6_len = sizeof(address), .sin6_family = AF_INET6 };
            CHECK(inet_pton(AF_INET6, "fe80:7::b", &address.sin6_addr) == 1);
            offset = LHFixtureAppend(bytes, offset, &address, sizeof(address));
        }
    }
    header.rtm_msglen = (unsigned short)offset;
    memcpy(bytes, &header, sizeof(header));
    return offset;
}

static LHRouteMessageView LHFixtureView(const uint8_t *bytes, size_t length, int operation) {
    LHRouteMessageView view;
    CHECK(LHRouteParseMessage(bytes, length, operation, &view));
    return view;
}

static void LHFixtureExpectUnchanged(uint8_t *bytes, size_t length, int operation, int family,
                                     bool valid) {
    uint8_t copy[4096];
    CHECK(length <= sizeof(copy));
    memcpy(copy, bytes, length);
    CHECK(LHRouteRewriteDump(bytes, length, operation, family) == valid);
    CHECK(memcmp(bytes, copy, length) == 0);
}

static void LHFixtureCheckIPv4(void) {
    uint8_t bytes[1024];
    uint8_t copy[1024];
    for (size_t operationIndex = 0; operationIndex < 3; operationIndex++) {
        const int operations[] = { NET_RT_FLAGS, NET_RT_DUMP, NET_RT_DUMP2 };
        int operation = operations[operationIndex];
        size_t length = LHFixtureBuildRoute(bytes, operation, AF_INET, false, true);
        memcpy(copy, bytes, length);
        LHRouteMessageView view = LHFixtureView(bytes, length, operation);
        CHECK(LHRouteRewriteDump(bytes, length, operation, AF_INET));
        CHECK(memcmp(bytes, copy, sizeof(struct rt_msghdr)) == 0);
        size_t gateway = view.addressOffsets[RTAX_GATEWAY];
        uint32_t address = 0;
        memcpy(&address, bytes + gateway + offsetof(struct sockaddr_in, sin_addr), sizeof(address));
        CHECK(ntohl(address) == 0xC0A80101U);
        uint8_t host = 0;
        CHECK(LHMitigationDeriveBytes(&LHRoutePolicy->config.buildSeed,
                                      &LHGeneratedPolicySeed_network_interface_ipv4_host,
                                      &LHRoutePolicy->appContext.scope,
                                      (const uint8_t *)"en0", 3, &host, 1));
        size_t local = view.addressOffsets[RTAX_IFA];
        memcpy(&address, bytes + local + offsetof(struct sockaddr_in, sin_addr), sizeof(address));
        CHECK(ntohl(address) == (0xC0A80100U | (20U + host % 180U)));
        CHECK(memcmp(bytes + view.addressOffsets[RTAX_DST], copy + view.addressOffsets[RTAX_DST],
                     sizeof(struct sockaddr_in)) == 0);
        CHECK(memcmp(bytes + view.addressOffsets[RTAX_NETMASK], copy + view.addressOffsets[RTAX_NETMASK], 4) == 0);
        memcpy(copy, bytes, length);
        CHECK(LHRouteRewriteDump(bytes, length, operation, AF_INET));
        CHECK(memcmp(bytes, copy, length) == 0);
    }

    /* Route mask length three still advances four bytes, never sizeof(long). */
    size_t length = LHFixtureBuildRoute(bytes, NET_RT_DUMP, AF_INET, false, true);
    LHRouteMessageView view = LHFixtureView(bytes, length, NET_RT_DUMP);
    bytes[view.addressOffsets[RTAX_NETMASK]] = 3;
    bytes[view.addressOffsets[RTAX_NETMASK] + 1] = 0xff;
    bytes[view.addressOffsets[RTAX_NETMASK] + 2] = 0xff;
    CHECK(LHRouteRewriteDump(bytes, length, NET_RT_DUMP, AF_INET));
    CHECK(bytes[view.addressOffsets[RTAX_NETMASK]] == 3);
    CHECK(bytes[view.addressOffsets[RTAX_NETMASK] + 1] == 0xff);
    CHECK(bytes[view.addressOffsets[RTAX_NETMASK] + 2] == 0xff);

    /* Caller buffers need not be aligned to any native struct. */
    length = LHFixtureBuildRoute(bytes + 1, NET_RT_DUMP, AF_INET, false, true);
    CHECK(LHRouteRewriteDump(bytes + 1, length, NET_RT_DUMP, AF_INET));
}

static void LHFixtureCheckIPv6AndLink(void) {
    uint8_t bytes[1024];
    uint8_t copy[1024];
    const char *const names[] = { "en0", "utun4" };
    for (size_t nameIndex = 0; nameIndex < 2; nameIndex++) {
        LHFixtureName = names[nameIndex];
        size_t length = LHFixtureBuildRoute(bytes, NET_RT_DUMP2, AF_INET6, true, true);
        LHRouteMessageView view = LHFixtureView(bytes, length, NET_RT_DUMP2);
        memcpy(copy, bytes, length);
        unsigned int nameCalls = LHFixtureNameCalls;
        CHECK(LHRouteRewriteDump(bytes, length, NET_RT_DUMP2, AF_INET6));
        CHECK(LHFixtureNameCalls == nameCalls);
        CHECK(memcmp(bytes, copy, sizeof(struct rt_msghdr2)) == 0);
        struct sockaddr_in6 gateway;
        memcpy(&gateway, bytes + view.addressOffsets[RTAX_GATEWAY], sizeof(gateway));
        struct in6_addr expected;
        CHECK(inet_pton(AF_INET6, "fe80::1", &expected) == 1);
        CHECK(memcmp(&gateway.sin6_addr, &expected, sizeof(expected)) == 0);
        CHECK(gateway.sin6_scope_id == (nameIndex == 0 ? 7U : 0U));
        struct sockaddr_in6 local;
        memcpy(&local, bytes + view.addressOffsets[RTAX_IFA], sizeof(local));
        uint8_t suffix[8];
        CHECK(LHRouteDeriveBytes(&LHGeneratedPolicySeed_network_interface_ipv6_suffix,
                                 LHFixtureName, suffix, sizeof(suffix)));
        CHECK(memcmp(local.sin6_addr.s6_addr + 8, suffix, sizeof(suffix)) == 0);
        CHECK(local.sin6_scope_id == (nameIndex == 0 ? 7U : 0U));

        size_t link = view.addressOffsets[RTAX_IFP];
        uint8_t mac[6];
        CHECK(LHRouteDeriveBytes(&LHGeneratedPolicySeed_network_interface_link_mac,
                                 LHFixtureName, mac, sizeof(mac)));
        mac[0] = (uint8_t)((mac[0] | 2) & 0xfe);
        size_t data = link + offsetof(struct sockaddr_dl, sdl_data);
        size_t nameLength = bytes[link + offsetof(struct sockaddr_dl, sdl_nlen)];
        CHECK(nameLength == 3);
        CHECK(memcmp(bytes + data + nameLength, mac, sizeof(mac)) == 0);
        CHECK(bytes[data + nameLength + 6] == 0x55 && bytes[data + nameLength + 7] == 0xaa);
        CHECK(bytes[link] == copy[link]);
        CHECK(memcmp(bytes + link + offsetof(struct sockaddr_dl, sdl_index),
                     copy + link + offsetof(struct sockaddr_dl, sdl_index), sizeof(uint16_t)) == 0);
        if (nameIndex == 0) {
            CHECK(memcmp(bytes + data, "en0", 3) == 0);
        } else {
            uint8_t alias = 0;
            const char *const aliases[] = { "en1", "en2", "en3" };
            CHECK(LHRouteDeriveBytes(&LHGeneratedPolicySeed_network_interface_name_alias,
                                     LHFixtureName, &alias, 1));
            CHECK(memcmp(bytes + data, aliases[alias % 3], 3) == 0);
            for (size_t offset = data + 3 + 8; offset < link + bytes[link]; offset++) {
                CHECK(bytes[offset] == 0);
            }
        }
    }
    LHFixtureName = "en0";

    size_t length = LHFixtureBuildRoute(bytes, NET_RT_DUMP, AF_INET6, false, true);
    LHRouteMessageView view = LHFixtureView(bytes, length, NET_RT_DUMP);
    struct sockaddr_in6 gateway;
    memcpy(&gateway, bytes + view.addressOffsets[RTAX_GATEWAY], sizeof(gateway));
    CHECK(inet_pton(AF_INET6, "2001:db8::1", &gateway.sin6_addr) == 1);
    memcpy(bytes + view.addressOffsets[RTAX_GATEWAY], &gateway, sizeof(gateway));
    LHFixtureExpectUnchanged(bytes, length, NET_RT_DUMP, AF_INET6, true);
    CHECK(inet_pton(AF_INET6, "fe80:8::1", &gateway.sin6_addr) == 1);
    memcpy(bytes + view.addressOffsets[RTAX_GATEWAY], &gateway, sizeof(gateway));
    LHFixtureExpectUnchanged(bytes, length, NET_RT_DUMP, AF_INET6, true);

    /* Change only the practical seed and scope; the route-local suffix follows each. */
    length = LHFixtureBuildRoute(bytes, NET_RT_DUMP, AF_INET6, false, true);
    CHECK(LHRouteRewriteDump(bytes, length, NET_RT_DUMP, AF_INET6));
    memcpy(copy, bytes, length);
    LHRoutePolicy->config.buildSeed.bytes[0] ^= 1;
    length = LHFixtureBuildRoute(bytes, NET_RT_DUMP, AF_INET6, false, true);
    CHECK(LHRouteRewriteDump(bytes, length, NET_RT_DUMP, AF_INET6));
    CHECK(memcmp(bytes + view.addressOffsets[RTAX_IFA], copy + view.addressOffsets[RTAX_IFA], sizeof(gateway)) != 0);
    LHRoutePolicy->config.buildSeed.bytes[0] ^= 1;
    LHRoutePolicy->appContext.scope.identifier[0] ^= 1;
    length = LHFixtureBuildRoute(bytes, NET_RT_DUMP, AF_INET6, false, true);
    CHECK(LHRouteRewriteDump(bytes, length, NET_RT_DUMP, AF_INET6));
    CHECK(memcmp(bytes + view.addressOffsets[RTAX_IFA], copy + view.addressOffsets[RTAX_IFA], sizeof(gateway)) != 0);
    LHRoutePolicy->appContext.scope.identifier[0] ^= 1;
}

static void LHFixtureCheckPassThroughAndMalformed(void) {
    uint8_t bytes[2048];
    uint8_t valid[1024];
    size_t length = LHFixtureBuildRoute(valid, NET_RT_DUMP, AF_INET, true, true);
    LHRouteMessageView view = LHFixtureView(valid, length, NET_RT_DUMP);
    for (size_t trial = 0; trial < 17; trial++) {
        memcpy(bytes, valid, length);
        LHRouteMessageHeader header = view.header;
        size_t size = length;
        switch (trial) {
            case 0: size = 1; break;
            case 1: size = sizeof(header) - 1; break;
            case 2: header.length = 0; break;
            case 3: header.length = (uint16_t)(length + 4); break;
            case 4: header.length--; break;
            case 5: header.version--; break;
            case 6: header.type = RTM_IFINFO; break;
            case 7: header.addresses |= 1U << 8; break;
            case 8: bytes[view.addressOffsets[RTAX_GATEWAY]] = 255; break;
            case 9: bytes[view.addressOffsets[RTAX_GATEWAY]] = 8; break;
            case 10: bytes[view.addressOffsets[RTAX_IFP] + offsetof(struct sockaddr_dl, sdl_nlen)] = 255; break;
            case 11: bytes[view.addressOffsets[RTAX_GATEWAY] + 1] = AF_UNIX; break;
            case 12: bytes[view.addressOffsets[RTAX_NETMASK]] = 1; break;
            case 13: bytes[view.addressOffsets[RTAX_IFP] + offsetof(struct sockaddr_dl, sdl_index)] = 8; break;
            case 14: bytes[view.addressOffsets[RTAX_IFP] + offsetof(struct sockaddr_dl, sdl_data)] = 0; break;
            case 15: bytes[view.addressOffsets[RTAX_GATEWAY]] = 0; break;
            case 16: bytes[view.addressOffsets[RTAX_IFA] + 1] = AF_LINK; break;
        }
        memcpy(bytes, &header, sizeof(header));
        LHFixtureExpectUnchanged(bytes, size, NET_RT_DUMP, AF_INET, false);
    }

    /* A valid first route must remain untouched when the next one is truncated. */
    memcpy(bytes, valid, length);
    memcpy(bytes + length, valid, length);
    LHFixtureExpectUnchanged(bytes, length * 2 - 1, NET_RT_DUMP, AF_INET, false);
    LHFixtureExpectUnchanged(bytes, length * 2, NET_RT_DUMP2, AF_INET, false);
    CHECK(LHRouteRewriteDump(bytes, length * 2, NET_RT_DUMP, AF_INET));
    CHECK(LHFixtureView(bytes + length, length, NET_RT_DUMP).header.length == length);

    memcpy(bytes, valid, length);
    LHRouteMessageHeader header = view.header;
    header.flags &= ~RTF_GATEWAY;
    memcpy(bytes, &header, sizeof(header));
    LHFixtureExpectUnchanged(bytes, length, NET_RT_DUMP, AF_INET, true);

    length = LHFixtureBuildRoute(bytes, NET_RT_DUMP, AF_INET, false, true);
    view = LHFixtureView(bytes, length, NET_RT_DUMP);
    struct sockaddr_dl link = { .sdl_len = sizeof(link), .sdl_family = AF_LINK, .sdl_index = 7 };
    /* Preserve a valid AF_LINK gateway shape, including the original local address. */
    size_t gateway = view.addressOffsets[RTAX_GATEWAY];
    size_t tail = length - gateway - sizeof(struct sockaddr_in);
    memmove(bytes + gateway + sizeof(link), bytes + gateway + sizeof(struct sockaddr_in), tail);
    memcpy(bytes + gateway, &link, sizeof(link));
    header = view.header;
    length += sizeof(link) - sizeof(struct sockaddr_in);
    header.length = (uint16_t)length;
    memcpy(bytes, &header, sizeof(header));
    LHFixtureExpectUnchanged(bytes, length, NET_RT_DUMP, AF_INET, true);

    length = LHFixtureBuildRoute(bytes, NET_RT_DUMP, AF_INET, false, true);
    LHFixtureName = 0;
    LHFixtureExpectUnchanged(bytes, length, NET_RT_DUMP, AF_INET, true);
    LHFixtureName = "lo0";
    LHFixtureExpectUnchanged(bytes, length, NET_RT_DUMP, AF_INET, true);
    LHFixtureName = "en0";
    LHPolicyEngine *policy = LHRoutePolicy;
    LHRoutePolicy = 0;
    LHFixtureExpectUnchanged(bytes, length, NET_RT_DUMP, AF_INET, false);
    LHRoutePolicy = policy;

    header = (LHRouteMessageHeader){ .length = sizeof(header), .version = RTM_VERSION, .type = RTM_GET };
    memcpy(bytes, &header, sizeof(header));
    LHFixtureExpectUnchanged(bytes, sizeof(header), NET_RT_DUMP, AF_INET, true);
    LHFixtureExpectUnchanged(bytes, 0, NET_RT_DUMP, AF_INET, true);
}

static void LHFixtureCheckLiveDumps(void) {
    if (getenv("LH_ROUTING_TEST_LIVE") == 0) {
        return;
    }
    LHRouteIfIndexToNameOriginal savedResolver = LHRouteIfIndexToNameOriginalImplementation;
    LHRouteIfIndexToNameOriginalImplementation =
        (LHRouteIfIndexToNameOriginal)dlsym(RTLD_DEFAULT, "if_indextoname");
    const int families[] = { AF_INET, AF_INET6 };
    const int operations[] = { NET_RT_FLAGS, NET_RT_DUMP, NET_RT_DUMP2 };
    unsigned int validated = 0;
    unsigned int unsupported = 0;
    unsigned int unavailable = 0;
    unsigned int rewritten = 0;
    for (size_t familyIndex = 0; familyIndex < 2; familyIndex++) {
        for (size_t operationIndex = 0; operationIndex < 3; operationIndex++) {
            int query[] = { CTL_NET, PF_ROUTE, 0, families[familyIndex], operations[operationIndex],
                            operations[operationIndex] == NET_RT_FLAGS ? RTF_GATEWAY : 0 };
            size_t capacity = 0;
            if (sysctl(query, 6, 0, &capacity, 0, 0) != 0) {
                unavailable++;
                continue;
            }
            uint8_t *bytes = malloc(capacity + 1);
            uint8_t *copy = malloc(capacity + 1);
            CHECK(bytes != 0 && copy != 0);
            size_t length = capacity;
            if (sysctl(query, 6, bytes, &length, 0, 0) != 0) {
                unavailable++;
                free(bytes);
                free(copy);
                continue;
            }
            CHECK(length <= capacity);
            memcpy(copy, bytes, length);
            if (LHRouteRewriteDump(bytes, length, query[4], query[3])) {
                validated++;
                for (size_t offset = 0; offset < length;) {
                    LHRouteMessageView before = LHFixtureView(copy + offset, length - offset, query[4]);
                    LHRouteMessageView after = LHFixtureView(bytes + offset, length - offset, query[4]);
                    CHECK(memcmp(&before.header, &after.header, sizeof(before.header)) == 0);
                    CHECK(LHRouteValidateMessageFamily(bytes + offset, &after, query[3]));
                    rewritten += memcmp(bytes + offset, copy + offset, before.header.length) != 0;
                    offset += before.header.length;
                }
            } else {
                unsupported++;
                CHECK(memcmp(bytes, copy, length) == 0);
                for (size_t offset = 0; offset < length;) {
                    LHRouteMessageView view;
                    bool parsed = LHRouteParseMessage(copy + offset, length - offset, query[4], &view);
                    if (!parsed || !LHRouteValidateMessageFamily(copy + offset, &view, query[3])) {
                        LHRouteMessageHeader header = { 0 };
                        size_t available = length - offset;
                        memcpy(&header, copy + offset, available < sizeof(header) ? available : sizeof(header));
                        printf("unsupported host route: family=%d op=%d offset=%zu length=%u type=%u addrs=0x%x parsed=%d\n",
                               query[3], query[4], offset, header.length, header.type, header.addresses, parsed);
                        size_t cursor = sizeof(header);
                        for (size_t slot = 0; slot < LHRouteAddressCount && cursor + 2 <= available; slot++) {
                            if ((header.addresses & (1U << slot)) == 0) {
                                continue;
                            }
                            size_t addressLength = copy[offset + cursor];
                            printf("  slot=%zu length=%zu family=%u\n", slot, addressLength, copy[offset + cursor + 1]);
                            cursor += addressLength == 0 ? 4 : (addressLength + 3U) & ~(size_t)3U;
                        }
                        break;
                    }
                    offset += view.header.length;
                }
            }
            free(bytes);
            free(copy);
        }
    }
    LHRouteIfIndexToNameOriginalImplementation = savedResolver;
    printf("live read-only route dumps: %u validated, %u unsupported, %u unavailable, %u messages rewritten\n",
           validated, unsupported, unavailable, rewritten);
}

static void LHFixtureCheckWrappers(void) {
    uint8_t output[4096];
    int query[7] = { CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_GATEWAY, 0 };
    LHFixtureSourceLength = LHFixtureBuildRoute(LHFixtureSource, NET_RT_FLAGS, AF_INET, false, true);
    LHFixtureErrno = EDOM;
    LHFixtureResult = 0;
    size_t length = sizeof(output);
    CHECK(LHRouteSysctlReplacement(query, 6, output, &length, 0, 0) == 0);
    CHECK(LHFixtureOriginalSymbol == 1 && errno == EDOM);
    CHECK(length == LHFixtureSourceLength);
    CHECK(memcmp(output, LHFixtureSource, length) != 0);
    length = sizeof(output);
    CHECK(LHRoutePrivateSysctlReplacement(query, 6, output, &length, 0, 0) == 0);
    CHECK(LHFixtureOriginalSymbol == 2 && errno == EDOM);

    length = 0;
    CHECK(LHRouteSysctlReplacement(query, 6, 0, &length, 0, 0) == 0);
    CHECK(length == LHFixtureSourceLength && errno == EDOM);
    length = LHFixtureSourceLength - 4;
    CHECK(LHRouteSysctlReplacement(query, 6, output, &length, 0, 0) == -1);
    CHECK(errno == ENOMEM && length == LHFixtureSourceLength);
    CHECK(memcmp(output, LHFixtureSource, length - 4) == 0);

    LHFixtureReportOversizedSuccess = true;
    length = LHFixtureSourceLength - 4;
    CHECK(LHRouteSysctlReplacement(query, 6, output, &length, 0, 0) == 0);
    CHECK(errno == EDOM && memcmp(output, LHFixtureSource, length - 4) == 0);
    LHFixtureReportOversizedSuccess = false;
    LHFixtureResult = 17;
    length = sizeof(output);
    CHECK(LHRouteSysctlReplacement(query, 6, output, &length, 0, 0) == 17);
    CHECK(errno == EDOM && memcmp(output, LHFixtureSource, length) == 0);
    LHFixtureResult = -1;
    length = sizeof(output);
    CHECK(LHRoutePrivateSysctlReplacement(query, 6, output, &length, 0, 0) == -1);
    CHECK(errno == EDOM && memcmp(output, LHFixtureSource, length) == 0);
    LHFixtureResult = 0;

    for (size_t trial = 0; trial < 10; trial++) {
        int unsupported[7];
        memcpy(unsupported, query, sizeof(query));
        unsigned int count = 6;
        void *newValue = 0;
        size_t newLength = 0;
        switch (trial) {
            case 0: newValue = &trial; newLength = 1; break;
            case 1: newLength = 1; break;
            case 2: count = 5; break;
            case 3: count = 7; break;
            case 4: unsupported[0] = CTL_KERN; break;
            case 5: unsupported[2] = 1; break;
            case 6: unsupported[3] = AF_UNSPEC; break;
            case 7: unsupported[4] = NET_RT_IFLIST; break;
            case 8: unsupported[4] = NET_RT_IFLIST2; break;
            case 9: unsupported[5] = RTF_UP | RTF_GATEWAY; break;
        }
        length = sizeof(output);
        CHECK(LHRouteSysctlReplacement(unsupported, count, output, &length, newValue, newLength) == 0);
        CHECK(errno == EDOM && memcmp(output, LHFixtureSource, length) == 0);
        CHECK(LHFixtureNewValue == newValue && LHFixtureNewLength == newLength);
    }
    CHECK(LHRouteSysctlReplacement(query, 6, 0, 0, 0, 0) == -1 && errno == EFAULT);

    /* A public implementation can call a covered private import; derive only once. */
    LHFixtureName = "utun7";
    LHFixtureSourceLength = LHFixtureBuildRoute(LHFixtureSource, NET_RT_FLAGS, AF_INET, true, true);
    uint8_t expected[4096];
    size_t expectedLength = sizeof(expected);
    CHECK(LHRouteSysctlReplacement(query, 6, expected, &expectedLength, 0, 0) == 0);
    LHRouteSysctlOriginalImplementation = LHFixtureNestedOriginal;
    length = sizeof(output);
    CHECK(LHRouteSysctlReplacement(query, 6, output, &length, 0, 0) == 0);
    CHECK(length == expectedLength && memcmp(output, expected, length) == 0);
    CHECK(LHRouteOriginalDepth == 0 && errno == EDOM);
    LHRouteSysctlOriginalImplementation = LHFixturePublicOriginal;
    LHRoutePrivateSysctlOriginalImplementation = 0;
    CHECK(LHRoutePrivateSysctlReplacement(query, 6, 0, 0, 0, 0) == -1 && errno == ENOSYS);
}

int main(void) {
    LHPolicyEngine policy = { 0 };
    CHECK(LHSeedParseUUID("11111111-2222-3333-4444-555555555555", &policy.config.buildSeed));
    const char *scope = "com.example.routing-fixture";
    policy.appContext.scope.mode = LHScopeModePerApp;
    policy.appContext.scope.identifierLength = strlen(scope);
    memcpy(policy.appContext.scope.identifier, scope, strlen(scope));
    policy.initialized = true;
    const LHHookBackendVTable vtable = { .hookImportedSymbol = LHFixtureHookImportedSymbol };
    LHHookBackend backend = { .vtable = &vtable };
    CHECK(!LHInterfaceInventoryInstallRoutingHooks(0, &policy));
    CHECK(!LHInterfaceInventoryInstallRoutingHooks(&backend, 0));
    CHECK(LHInterfaceInventoryInstallRoutingHooks(&backend, &policy));
    CHECK(LHFixtureHookCalls == 2);
    LHRouteIfIndexToNameOriginalImplementation = LHFixtureResolveName;

    LHFixtureCheckIPv4();
    LHFixtureCheckIPv6AndLink();
    LHFixtureCheckPassThroughAndMalformed();
    LHFixtureCheckLiveDumps();
    LHFixtureCheckWrappers();
    printf("routing table check passed (%u assertions, ASan/UBSan)\n", LHFixtureAssertions);
    return 0;
}
