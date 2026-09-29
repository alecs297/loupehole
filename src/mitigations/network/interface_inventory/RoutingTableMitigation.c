#include "RoutingTableMitigation.h"

#include "LHGeneratedPolicySeeds.h"
#include "LHMitigationValues.h"

#include <arpa/inet.h>
#include <dlfcn.h>
#include <errno.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <netinet/in.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/sysctl.h>

enum {
    LHRouteVersion = 5,
    LHRouteGet = 0x4,
    LHRouteGet2 = 0x14,
    LHRouteGatewayFlag = 0x2,
    LHRouteDestination = 0,
    LHRouteGateway = 1,
    LHRouteNetmask = 2,
    LHRouteGenmask = 3,
    LHRouteInterface = 4,
    LHRouteLocalAddress = 5,
    LHRouteAddressCount = 8
};

/* Darwin's GET and GET2 headers have this same 92-byte layout. iOS SDKs omit net/route.h. */
typedef struct LHRouteMessageHeader {
    uint16_t length;
    uint8_t version;
    uint8_t type;
    uint16_t interfaceIndex;
    uint16_t padding;
    int32_t flags;
    uint32_t addresses;
    uint32_t metadata[5];
    uint32_t metrics[14];
} LHRouteMessageHeader;

_Static_assert(sizeof(LHRouteMessageHeader) == 92, "Darwin route header size");

#if __has_include(<net/route.h>)
#include <net/route.h>
_Static_assert(sizeof(LHRouteMessageHeader) == sizeof(struct rt_msghdr), "GET header size");
_Static_assert(sizeof(LHRouteMessageHeader) == sizeof(struct rt_msghdr2), "GET2 header size");
_Static_assert(offsetof(LHRouteMessageHeader, flags) == offsetof(struct rt_msghdr, rtm_flags), "route flags offset");
_Static_assert(offsetof(LHRouteMessageHeader, addresses) == offsetof(struct rt_msghdr2, rtm_addrs), "route addresses offset");
#endif

typedef struct LHRouteMessageView {
    LHRouteMessageHeader header;
    size_t addressOffsets[LHRouteAddressCount];
} LHRouteMessageView;

typedef int (*LHRouteSysctlOriginal)(int *, unsigned int, void *, size_t *, void *, size_t);
typedef char *(*LHRouteIfIndexToNameOriginal)(unsigned int, char *);

static LHRouteSysctlOriginal LHRouteSysctlOriginalImplementation;
static LHRouteSysctlOriginal LHRoutePrivateSysctlOriginalImplementation;
static LHRouteIfIndexToNameOriginal LHRouteIfIndexToNameOriginalImplementation;
static LHPolicyEngine *LHRoutePolicy;
static _Thread_local unsigned int LHRouteOriginalDepth;

static bool LHRouteNameLooksSensitive(const char *name) {
    return strncmp(name, "tap", 3) == 0 || strncmp(name, "tun", 3) == 0 ||
           strncmp(name, "utun", 4) == 0 || strncmp(name, "ppp", 3) == 0 ||
           strncmp(name, "ipsec", 5) == 0;
}

static bool LHRouteQueryIsSupported(const int *name, unsigned int count,
                                    const void *newValue, size_t newLength) {
    if (name == 0 || count != 6 || newValue != 0 || newLength != 0 ||
        name[0] != CTL_NET || name[1] != PF_ROUTE || name[2] != 0 ||
        (name[3] != AF_INET && name[3] != AF_INET6)) {
        return false;
    }
    if (name[4] == NET_RT_FLAGS) {
        return name[5] == LHRouteGatewayFlag;
    }
    return (name[4] == NET_RT_DUMP || name[4] == NET_RT_DUMP2) && name[5] == 0;
}

static bool LHRouteValidateSockaddr(const uint8_t *address, size_t length, size_t slot) {
    if (slot == LHRouteNetmask || slot == LHRouteGenmask) {
        /* Radix masks are compressed raw bytes; their family byte may itself be mask bits. */
        return length == 0 ||
               (length >= 2 && length <= sizeof(struct sockaddr_in6));
    }
    if (length < 2) {
        return false;
    }
    switch (address[1]) {
        case AF_INET:
            return length == sizeof(struct sockaddr_in);
        case AF_INET6:
            return length == sizeof(struct sockaddr_in6);
        case AF_LINK: {
            size_t dataOffset = offsetof(struct sockaddr_dl, sdl_data);
            if (length < dataOffset) {
                return false;
            }
            size_t payload = (size_t)address[offsetof(struct sockaddr_dl, sdl_nlen)] +
                             (size_t)address[offsetof(struct sockaddr_dl, sdl_alen)] +
                             (size_t)address[offsetof(struct sockaddr_dl, sdl_slen)];
            return payload <= length - dataOffset;
        }
        default:
            return false;
    }
}

static bool LHRouteParseMessage(const uint8_t *message, size_t available,
                                int operation, LHRouteMessageView *view) {
    if (available < sizeof(view->header)) {
        return false;
    }
    memset(view, 0, sizeof(*view));
    memcpy(&view->header, message, sizeof(view->header));
    size_t length = view->header.length;
    if (length < sizeof(view->header) || length > available || length % 4 != 0 ||
        view->header.version != LHRouteVersion ||
        view->header.type != (operation == NET_RT_DUMP2 ? LHRouteGet2 : LHRouteGet) ||
        (view->header.addresses & ~((1U << LHRouteAddressCount) - 1U)) != 0) {
        return false;
    }

    size_t offset = sizeof(view->header);
    for (size_t slot = 0; slot < LHRouteAddressCount; slot++) {
        if ((view->header.addresses & (1U << slot)) == 0) {
            continue;
        }
        if (length - offset < 2) {
            return false;
        }
        size_t sockaddrLength = message[offset];
        /* XNU uses ROUNDUP32, including a four-byte slot for a zero-length mask. */
        size_t step = sockaddrLength == 0 ? 4 : (sockaddrLength + 3U) & ~(size_t)3U;
        if (step > length - offset ||
            !LHRouteValidateSockaddr(message + offset, sockaddrLength, slot)) {
            return false;
        }
        view->addressOffsets[slot] = offset;
        offset += step;
    }
    return offset == length;
}

static bool LHRouteValidateMessageFamily(const uint8_t *message,
                                         const LHRouteMessageView *view, int family) {
    for (size_t slot = 0; slot < LHRouteAddressCount; slot++) {
        size_t offset = view->addressOffsets[slot];
        if (offset == 0 || slot == LHRouteNetmask || slot == LHRouteGenmask) {
            continue;
        }
        int addressFamily = message[offset + 1];
        if (slot == LHRouteInterface) {
            if (addressFamily != AF_LINK) {
                return false;
            }
            uint16_t index = 0;
            memcpy(&index, message + offset + offsetof(struct sockaddr_dl, sdl_index), sizeof(index));
            size_t nameLength = message[offset + offsetof(struct sockaddr_dl, sdl_nlen)];
            if ((index != 0 && view->header.interfaceIndex != 0 && index != view->header.interfaceIndex) ||
                nameLength >= IFNAMSIZ ||
                memchr(message + offset + offsetof(struct sockaddr_dl, sdl_data), 0, nameLength) != 0) {
                return false;
            }
        } else if (addressFamily != family && !(slot == LHRouteGateway && addressFamily == AF_LINK)) {
            return false;
        }
    }
    return true;
}

static bool LHRouteCopyOriginalName(const uint8_t *message, const LHRouteMessageView *view,
                                    char name[IFNAMSIZ]) {
    size_t linkOffset = view->addressOffsets[LHRouteInterface];
    memset(name, 0, IFNAMSIZ);
    if (linkOffset != 0 && message[linkOffset + 1] == AF_LINK) {
        const uint8_t *link = message + linkOffset;
        size_t nameLength = link[offsetof(struct sockaddr_dl, sdl_nlen)];
        if (nameLength > 0 && nameLength < IFNAMSIZ) {
            memcpy(name, link + offsetof(struct sockaddr_dl, sdl_data), nameLength);
            if (memchr(name, 0, nameLength) == 0) {
                return true;
            }
        }
    }
    if (view->header.interfaceIndex == 0 || LHRouteIfIndexToNameOriginalImplementation == 0) {
        return false;
    }
    memset(name, 0, IFNAMSIZ);
    return LHRouteIfIndexToNameOriginalImplementation(view->header.interfaceIndex, name) != 0 &&
           name[0] != 0 && memchr(name, 0, IFNAMSIZ) != 0;
}

static bool LHRouteDeriveBytes(const LHPolicySeed *seed, const char *name,
                               uint8_t *bytes, size_t count) {
    return LHRoutePolicy != 0 &&
           LHMitigationDeriveBytes(&LHRoutePolicy->config.buildSeed, seed,
                                   &LHRoutePolicy->appContext.scope,
                                   (const uint8_t *)name, strlen(name), bytes, count);
}

static bool LHRouteCopyIPv6Zone(const struct sockaddr_in6 *address,
                                uint16_t interfaceIndex, uint32_t *zone) {
    *zone = address->sin6_scope_id;
    if (!IN6_IS_ADDR_LINKLOCAL(&address->sin6_addr)) {
        return true;
    }
    uint16_t embedded = ((uint16_t)address->sin6_addr.s6_addr[2] << 8) |
                        address->sin6_addr.s6_addr[3];
    if (embedded != 0 &&
        ((interfaceIndex != 0 && embedded != interfaceIndex) ||
         (*zone != 0 && embedded != *zone))) {
        return false;
    }
    if (*zone == 0) {
        *zone = embedded;
    }
    return interfaceIndex == 0 || *zone == 0 || *zone == interfaceIndex;
}

static void LHRouteRewriteMessage(uint8_t *message, const LHRouteMessageView *view, int family) {
    size_t gatewayOffset = view->addressOffsets[LHRouteGateway];
    if ((view->header.flags & LHRouteGatewayFlag) == 0 || gatewayOffset == 0 ||
        message[gatewayOffset + 1] != family) {
        return;
    }

    struct sockaddr_in gateway4;
    struct sockaddr_in6 gateway6;
    if (family == AF_INET) {
        memcpy(&gateway4, message + gatewayOffset, sizeof(gateway4));
        uint32_t original = ntohl(gateway4.sin_addr.s_addr);
        if (original == 0 || (original >> 24) == 127 || (original >> 24) >= 224) {
            return;
        }
        gateway4.sin_addr.s_addr = htonl(0xC0A80101U);
    } else {
        memcpy(&gateway6, message + gatewayOffset, sizeof(gateway6));
        uint32_t zone = 0;
        if (!IN6_IS_ADDR_LINKLOCAL(&gateway6.sin6_addr) ||
            !LHRouteCopyIPv6Zone(&gateway6, view->header.interfaceIndex, &zone)) {
            return;
        }
        memset(&gateway6.sin6_addr, 0, sizeof(gateway6.sin6_addr));
        gateway6.sin6_addr.s6_addr[0] = 0xfe;
        gateway6.sin6_addr.s6_addr[1] = 0x80;
        gateway6.sin6_addr.s6_addr[15] = 1;
        gateway6.sin6_scope_id = zone;
    }

    size_t localOffset = view->addressOffsets[LHRouteLocalAddress];
    size_t linkOffset = view->addressOffsets[LHRouteInterface];
    char name[IFNAMSIZ];
    bool haveName = LHRouteCopyOriginalName(message, view, name);
    if ((!haveName && (localOffset != 0 || linkOffset != 0)) ||
        (haveName && strncmp(name, "lo", 2) == 0)) {
        return;
    }
    bool sensitive = haveName && LHRouteNameLooksSensitive(name);

    struct sockaddr_in local4;
    struct sockaddr_in6 local6;
    uint8_t localBytes[8];
    if (localOffset != 0) {
        if (message[localOffset + 1] != family) {
            return;
        }
        if (family == AF_INET) {
            if (!LHRouteDeriveBytes(&LHGeneratedPolicySeed_network_interface_ipv4_host,
                                    name, localBytes, 1)) {
                return;
            }
            memcpy(&local4, message + localOffset, sizeof(local4));
            local4.sin_addr.s_addr = htonl(0xC0A80100U | (20U + localBytes[0] % 180U));
        } else {
            if (!LHRouteDeriveBytes(&LHGeneratedPolicySeed_network_interface_ipv6_suffix,
                                    name, localBytes, sizeof(localBytes))) {
                return;
            }
            memcpy(&local6, message + localOffset, sizeof(local6));
            uint32_t zone = 0;
            if (!LHRouteCopyIPv6Zone(&local6, view->header.interfaceIndex, &zone)) {
                return;
            }
            memset(&local6.sin6_addr, 0, sizeof(local6.sin6_addr));
            local6.sin6_addr.s6_addr[0] = 0xfe;
            local6.sin6_addr.s6_addr[1] = 0x80;
            memcpy(local6.sin6_addr.s6_addr + 8, localBytes, sizeof(localBytes));
            local6.sin6_scope_id = sensitive ? 0 : zone;
        }
    }

    uint8_t linkBytes[6];
    uint8_t aliasByte = 0;
    const char *alias = 0;
    size_t macLength = 0;
    if (linkOffset != 0) {
        if (message[linkOffset + 1] != AF_LINK) {
            return;
        }
        macLength = message[linkOffset + offsetof(struct sockaddr_dl, sdl_alen)];
        if (macLength >= sizeof(linkBytes)) {
            if (!LHRouteDeriveBytes(&LHGeneratedPolicySeed_network_interface_link_mac,
                                    name, linkBytes, sizeof(linkBytes))) {
                return;
            }
            linkBytes[0] = (uint8_t)((linkBytes[0] | 0x02U) & 0xfeU);
        }
        if (sensitive) {
            static const char *const aliases[] = { "en1", "en2", "en3" };
            if (!LHRouteDeriveBytes(&LHGeneratedPolicySeed_network_interface_name_alias,
                                    name, &aliasByte, sizeof(aliasByte)) ||
                message[linkOffset + offsetof(struct sockaddr_dl, sdl_nlen)] < 3) {
                return;
            }
            alias = aliases[aliasByte % 3];
        }
    }

    if (family == AF_INET) {
        memcpy(message + gatewayOffset, &gateway4, sizeof(gateway4));
        if (localOffset != 0) {
            memcpy(message + localOffset, &local4, sizeof(local4));
        }
    } else {
        if (sensitive) {
            gateway6.sin6_scope_id = 0;
        }
        memcpy(message + gatewayOffset, &gateway6, sizeof(gateway6));
        if (localOffset != 0) {
            memcpy(message + localOffset, &local6, sizeof(local6));
        }
    }
    if (linkOffset != 0) {
        uint8_t *link = message + linkOffset;
        size_t nameLength = link[offsetof(struct sockaddr_dl, sdl_nlen)];
        size_t dataOffset = offsetof(struct sockaddr_dl, sdl_data);
        if (macLength >= sizeof(linkBytes)) {
            memcpy(link + dataOffset + nameLength, linkBytes, sizeof(linkBytes));
        }
        if (alias != 0) {
            size_t tailLength = macLength + link[offsetof(struct sockaddr_dl, sdl_slen)];
            memmove(link + dataOffset + 3, link + dataOffset + nameLength, tailLength);
            memcpy(link + dataOffset, alias, 3);
            memset(link + dataOffset + 3 + tailLength, 0,
                   link[0] - dataOffset - 3 - tailLength);
            link[offsetof(struct sockaddr_dl, sdl_nlen)] = 3;
        }
    }
}

static bool LHRouteRewriteDump(uint8_t *bytes, size_t length, int operation, int family) {
    if (LHRoutePolicy == 0 || bytes == 0 || (family != AF_INET && family != AF_INET6)) {
        return false;
    }
    LHRouteMessageView view;
    /* Validate the entire dump before changing any caller-owned bytes. */
    for (size_t offset = 0; offset < length; offset += view.header.length) {
        if (!LHRouteParseMessage(bytes + offset, length - offset, operation, &view) ||
            !LHRouteValidateMessageFamily(bytes + offset, &view, family)) {
            return false;
        }
    }
    for (size_t offset = 0; offset < length; offset += view.header.length) {
        if (!LHRouteParseMessage(bytes + offset, length - offset, operation, &view)) {
            return false;
        }
        LHRouteRewriteMessage(bytes + offset, &view, family);
    }
    return true;
}

static int LHRouteCallSysctl(LHRouteSysctlOriginal original, int *name, unsigned int count,
                             void *oldValue, size_t *oldLength, void *newValue, size_t newLength) {
    if (original == 0) {
        errno = ENOSYS;
        return -1;
    }
    bool queryMatches = LHRouteQueryIsSupported(name, count, newValue, newLength);
    bool rewrite = queryMatches && LHRouteOriginalDepth == 0 &&
                   oldValue != 0 && oldLength != 0;
    size_t capacity = rewrite ? *oldLength : 0;
    int operation = rewrite ? name[4] : 0;
    int family = rewrite ? name[3] : 0;
    if (queryMatches) LHRouteOriginalDepth++;
    int result = original(name, count, oldValue, oldLength, newValue, newLength);
    int savedErrno = errno;
    if (queryMatches) LHRouteOriginalDepth--;
    if (rewrite && result == 0 && *oldLength <= capacity) {
        LHRouteRewriteDump(oldValue, *oldLength, operation, family);
    }
    errno = savedErrno;
    return result;
}

static int LHRouteSysctlReplacement(int *name, unsigned int count, void *oldValue,
                                   size_t *oldLength, void *newValue, size_t newLength) {
    return LHRouteCallSysctl(LHRouteSysctlOriginalImplementation, name, count,
                             oldValue, oldLength, newValue, newLength);
}

static int LHRoutePrivateSysctlReplacement(int *name, unsigned int count, void *oldValue,
                                          size_t *oldLength, void *newValue, size_t newLength) {
    return LHRouteCallSysctl(LHRoutePrivateSysctlOriginalImplementation, name, count,
                             oldValue, oldLength, newValue, newLength);
}

bool LHInterfaceInventoryInstallRoutingHooks(LHHookBackend *backend, LHPolicyEngine *policy) {
    if (backend == 0 || policy == 0) {
        return false;
    }
    LHRoutePolicy = policy;
    /* Resolve the original name so scoped derivation does not use a previously aliased import. */
    LHRouteIfIndexToNameOriginalImplementation =
        (LHRouteIfIndexToNameOriginal)dlsym(RTLD_DEFAULT, "if_indextoname");
    bool installed = LHHookBackendHookImportedSymbol(backend, "sysctl",
                                                     (void *)LHRouteSysctlReplacement,
                                                     (void **)&LHRouteSysctlOriginalImplementation);
    installed = LHHookBackendHookImportedSymbol(backend, "__sysctl",
                                                 (void *)LHRoutePrivateSysctlReplacement,
                                                 (void **)&LHRoutePrivateSysctlOriginalImplementation) || installed;
    return installed;
}
