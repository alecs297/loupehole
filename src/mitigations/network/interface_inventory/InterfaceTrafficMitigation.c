#include "InterfaceTrafficMitigation.h"

#include <errno.h>
#include <net/if_dl.h>
#include <netinet/in.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>

#if __has_include(<net/route.h>)
#include <net/route.h>
#else
// iOS SDKs omit route.h; these are XNU's stable interface-message tags and address slots.
enum {
    RTM_VERSION = 5, RTM_IFINFO = 0xe, RTM_NEWADDR = 0xc,
    RTM_IFINFO2 = 0x12, RTM_NEWMADDR2 = 0x13,
    RTAX_NETMASK = 2, RTAX_IFP = 4, RTAX_IFA = 5, RTAX_BRD = 7, RTAX_MAX = 8
};
#endif

typedef int (*LHInterfaceTrafficSysctlOriginal)(int *, u_int, void *, size_t *, void *, size_t);

typedef struct LHInterfaceTrafficMessage {
    size_t length;
    uint8_t type;
    unsigned int index;
    int *flags;
    struct if_data *data32;
    struct if_data64 *data64;
    struct sockaddr *addresses[RTAX_MAX];
} LHInterfaceTrafficMessage;

static LHInterfaceTrafficSysctlOriginal LHTrafficSysctlOriginal;
static LHInterfaceTrafficSysctlOriginal LHTrafficPrivateSysctlOriginal;
static LHPolicyEngine *LHTrafficPolicy;
static _Thread_local unsigned int LHTrafficOriginalListDepth;
static _Thread_local unsigned int LHTrafficRawDepth;

void LHInterfaceTrafficBeginOriginalList(void) {
    LHTrafficOriginalListDepth++;
}

void LHInterfaceTrafficEndOriginalList(void) {
    if (LHTrafficOriginalListDepth != 0) {
        LHTrafficOriginalListDepth--;
    }
}

static bool LHInterfaceTrafficParseMessage(uint8_t *buffer, size_t available, int query,
                                           LHInterfaceTrafficMessage *message) {
    if (available < 4) {
        return false;
    }
    uint16_t length = 0;
    memcpy(&length, buffer, sizeof(length));
    if (length < 4 || length > available || (length & 3U) != 0 || buffer[2] != RTM_VERSION) {
        return false;
    }

    memset(message, 0, sizeof(*message));
    message->length = length;
    message->type = buffer[3];
    size_t headerLength = 0;
    int addressMask = 0;
    switch (buffer[3]) {
        case RTM_IFINFO: {
            if (query != NET_RT_IFLIST || length < sizeof(struct if_msghdr)) {
                return false;
            }
            struct if_msghdr *header = (struct if_msghdr *)buffer;
            headerLength = sizeof(*header);
            message->index = header->ifm_index;
            message->flags = &header->ifm_flags;
            message->data32 = &header->ifm_data;
            addressMask = header->ifm_addrs;
            break;
        }
        case RTM_IFINFO2: {
            if (query != NET_RT_IFLIST2 || length < sizeof(struct if_msghdr2)) {
                return false;
            }
            struct if_msghdr2 *header = (struct if_msghdr2 *)buffer;
            headerLength = sizeof(*header);
            message->index = header->ifm_index;
            message->flags = &header->ifm_flags;
            message->data64 = &header->ifm_data;
            addressMask = header->ifm_addrs;
            break;
        }
        case RTM_NEWADDR: {
            if (length < sizeof(struct ifa_msghdr)) {
                return false;
            }
            struct ifa_msghdr *header = (struct ifa_msghdr *)buffer;
            headerLength = sizeof(*header);
            message->index = header->ifam_index;
            message->flags = &header->ifam_flags;
            addressMask = header->ifam_addrs;
            break;
        }
        case RTM_NEWMADDR2: {
            if (query != NET_RT_IFLIST2 || length < sizeof(struct ifma_msghdr2)) {
                return false;
            }
            struct ifma_msghdr2 *header = (struct ifma_msghdr2 *)buffer;
            headerLength = sizeof(*header);
            message->index = header->ifmam_index;
            message->flags = &header->ifmam_flags;
            addressMask = header->ifmam_addrs;
            break;
        }
        default:
            return false;
    }
    if ((addressMask & ~((1U << RTAX_MAX) - 1U)) != 0) {
        return false;
    }

    size_t offset = headerLength;
    for (unsigned int index = 0; index < RTAX_MAX; index++) {
        if ((addressMask & (1U << index)) == 0) {
            continue;
        }
        if (offset > length || length - offset < 2) {
            return false;
        }
        struct sockaddr *address = (struct sockaddr *)(buffer + offset);
        size_t addressLength = address->sa_len;
        size_t padded = addressLength == 0 ? 4 : (addressLength + 3U) & ~3U;
        if ((addressLength != 0 && addressLength < 2) || padded > length - offset) {
            return false;
        }
        if (index != RTAX_NETMASK &&
            ((address->sa_family == AF_INET && addressLength < sizeof(struct sockaddr_in)) ||
             (address->sa_family == AF_INET6 && addressLength < sizeof(struct sockaddr_in6)))) {
            return false;
        }
        if (address->sa_family == AF_LINK) {
            size_t dataOffset = offsetof(struct sockaddr_dl, sdl_data);
            if (addressLength < dataOffset) {
                return false;
            }
            struct sockaddr_dl *link = (struct sockaddr_dl *)address;
            size_t used = (size_t)link->sdl_nlen + link->sdl_alen + link->sdl_slen;
            if (used > addressLength - dataOffset || link->sdl_nlen >= IFNAMSIZ ||
                memchr(link->sdl_data, 0, link->sdl_nlen) != 0) {
                return false;
            }
        }
        message->addresses[index] = address;
        offset += padded;
    }

    if (message->data32 != 0 || message->data64 != 0) {
        struct sockaddr *address = message->addresses[RTAX_IFP];
        if (address == 0 || address->sa_family != AF_LINK ||
            ((struct sockaddr_dl *)address)->sdl_nlen == 0) {
            return false;
        }
    }
    return offset == length;
}

static bool LHInterfaceTrafficFindName(uint8_t *original, size_t length, int query,
                                       unsigned int interfaceIndex, char name[IFNAMSIZ]) {
    for (size_t offset = 0; offset < length;) {
        LHInterfaceTrafficMessage message;
        if (!LHInterfaceTrafficParseMessage(original + offset, length - offset, query, &message)) {
            return false;
        }
        if ((message.data32 != 0 || message.data64 != 0) && message.index == interfaceIndex) {
            struct sockaddr_dl *link = (struct sockaddr_dl *)message.addresses[RTAX_IFP];
            memcpy(name, link->sdl_data, link->sdl_nlen);
            name[link->sdl_nlen] = '\0';
            return true;
        }
        offset += message.length;
    }
    return false;
}

static void LHInterfaceTrafficRewriteAddress(LHInterfaceTrafficMessage *message, char *name) {
    struct sockaddr *address = message->addresses[RTAX_IFA];
    struct sockaddr *mask = message->addresses[RTAX_NETMASK];
    struct sockaddr_storage fullMask = { 0 };
    size_t addressOffset = 0, addressSize = 0;
    if (address != 0 && mask != 0) {
        if (address->sa_family == AF_INET) {
            addressOffset = offsetof(struct sockaddr_in, sin_addr);
            addressSize = sizeof(struct in_addr);
            fullMask.ss_len = sizeof(struct sockaddr_in);
        } else if (address->sa_family == AF_INET6) {
            addressOffset = offsetof(struct sockaddr_in6, sin6_addr);
            addressSize = sizeof(struct in6_addr);
            fullMask.ss_len = sizeof(struct sockaddr_in6);
        }
        if (addressSize != 0) {
            size_t copyLength = mask->sa_len;
            if (copyLength > sizeof(fullMask)) {
                copyLength = sizeof(fullMask);
            }
            memcpy(&fullMask, mask, copyLength);
            fullMask.ss_family = address->sa_family;
        }
    }
    struct ifaddrs entry = { 0 };
    entry.ifa_name = name;
    entry.ifa_flags = (unsigned int)*message->flags;
    entry.ifa_addr = address;
    entry.ifa_netmask = addressSize == 0 ? 0 : (struct sockaddr *)&fullMask;
    entry.ifa_dstaddr = message->addresses[RTAX_BRD];
    LHInterfaceInventoryRewriteEntry(&entry);
    if (message->data32 != 0 || message->data64 != 0) {
        *message->flags = (int)entry.ifa_flags;
    }

    if (addressSize != 0 && mask->sa_len > addressOffset) {
        size_t writable = mask->sa_len - addressOffset;
        if (writable > addressSize) {
            writable = addressSize;
        }
        memcpy((uint8_t *)mask + addressOffset, (uint8_t *)&fullMask + addressOffset, writable);
    }
}

bool LHInterfaceTrafficShapeBuffer(LHPolicyEngine *policy, void *buffer, size_t length,
                                   int query, const LHInterfaceTrafficSnapshot *snapshot) {
    if (policy == 0 || buffer == 0 || snapshot == 0 || length == 0 ||
        length > 16ULL * 1024ULL * 1024ULL ||
        (query != NET_RT_IFLIST && query != NET_RT_IFLIST2)) {
        return false;
    }

    // Stage the complete dump so malformed messages or failed derivation never leave a partial rewrite.
    uint8_t *original = malloc(length);
    uint8_t *shaped = malloc(length);
    if (original == 0 || shaped == 0) {
        free(original);
        free(shaped);
        return false;
    }
    memcpy(original, buffer, length);
    memcpy(shaped, buffer, length);
    bool valid = true;
    for (size_t offset = 0; valid && offset < length;) {
        LHInterfaceTrafficMessage message;
        if (!LHInterfaceTrafficParseMessage(shaped + offset, length - offset, query, &message)) {
            valid = false;
            break;
        }
        char name[IFNAMSIZ] = { 0 };
        if (!LHInterfaceTrafficFindName(original, length, query, message.index, name)) {
            valid = false;
            break;
        }
        bool loopback = strncmp(name, "lo", 2) == 0;
        if (!loopback && (message.data32 != 0 || message.data64 != 0)) {
            LHInterfaceTrafficValues values;
            if (!LHInterfaceTrafficCopyValues(policy, name, snapshot, &values)) {
                valid = false;
                break;
            }
            if (message.data32 != 0) {
                LHInterfaceTrafficApply32(message.data32, name, snapshot, &values);
            } else {
                LHInterfaceTrafficApply64(message.data64, name, snapshot, &values);
                struct if_msghdr2 *header = (struct if_msghdr2 *)(shaped + offset);
                header->ifm_snd_len = 0;
                header->ifm_snd_drops = (int)values.inputDrops;
            }
        }
        if (message.type != RTM_NEWMADDR2) {
            LHInterfaceTrafficRewriteAddress(&message, name);
        }
        if (message.addresses[RTAX_IFP] != 0) {
            struct ifaddrs entry = { 0 };
            entry.ifa_name = name;
            entry.ifa_flags = (unsigned int)*message.flags;
            entry.ifa_addr = message.addresses[RTAX_IFP];
            LHInterfaceInventoryRewriteEntry(&entry);
            if (message.data32 != 0 || message.data64 != 0) {
                *message.flags = (int)entry.ifa_flags;
            }
            LHInterfaceInventoryRewriteSensitiveEntryName(&entry);
        }
        offset += message.length;
    }
    if (valid) {
        memcpy(buffer, shaped, length);
    }
    free(shaped);
    free(original);
    return valid;
}

static int LHInterfaceTrafficSysctlRead(LHInterfaceTrafficSysctlOriginal original,
                                        int *name, u_int count, void *output,
                                        size_t *outputLength, void *input, size_t inputLength) {
    if (original == 0) {
        errno = ENOSYS;
        return -1;
    }
    size_t capacity = output == 0 || outputLength == 0 ? 0 : *outputLength;
    bool queryMatches = input == 0 && inputLength == 0 && name != 0 && count == 6 &&
        name[0] == CTL_NET && name[1] == PF_ROUTE && name[2] == 0 &&
        (name[3] == 0 || name[3] == AF_INET || name[3] == AF_INET6 || name[3] == AF_LINK) &&
        (name[4] == NET_RT_IFLIST || name[4] == NET_RT_IFLIST2);
    bool nested = LHTrafficRawDepth != 0;
    if (queryMatches) LHTrafficRawDepth++;
    int result = original(name, count, output, outputLength, input, inputLength);
    int originalErrno = errno;
    if (queryMatches) LHTrafficRawDepth--;
    if (result == 0 && queryMatches && !nested && LHTrafficOriginalListDepth == 0 &&
        output != 0 && outputLength != 0 && *outputLength <= capacity) {
        LHInterfaceTrafficSnapshot snapshot;
        if (LHInterfaceTrafficCopySnapshot(&snapshot)) {
            (void)LHInterfaceTrafficShapeBuffer(LHTrafficPolicy, output, *outputLength, name[4], &snapshot);
        }
    }
    errno = originalErrno;
    return result;
}

static int LHInterfaceTrafficSysctlReplacement(int *name, u_int count, void *output,
                                              size_t *outputLength, void *input, size_t inputLength) {
    return LHInterfaceTrafficSysctlRead(LHTrafficSysctlOriginal, name, count, output,
                                        outputLength, input, inputLength);
}

static int LHInterfaceTrafficPrivateSysctlReplacement(int *name, u_int count, void *output,
                                                     size_t *outputLength, void *input, size_t inputLength) {
    return LHInterfaceTrafficSysctlRead(LHTrafficPrivateSysctlOriginal, name, count, output,
                                        outputLength, input, inputLength);
}

bool LHInterfaceInventoryInstallTrafficHooks(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHTrafficPolicy = policy;
    bool installed = LHHookBackendHookImportedSymbol(backend, "sysctl",
                                                    (void *)LHInterfaceTrafficSysctlReplacement,
                                                    (void **)&LHTrafficSysctlOriginal);
    return LHHookBackendHookImportedSymbol(backend, "__sysctl",
                                           (void *)LHInterfaceTrafficPrivateSysctlReplacement,
                                           (void **)&LHTrafficPrivateSysctlOriginal) || installed;
}
