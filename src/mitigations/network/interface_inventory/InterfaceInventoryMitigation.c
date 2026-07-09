#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"

#include <arpa/inet.h>
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <ifaddrs.h>
#include <Network/Network.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <net/if_var.h>
#include <netinet/in.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/sysctl.h>
#include <sys/time.h>
#include <time.h>

typedef int (*LHGetIfAddrsOriginal)(struct ifaddrs **interfaces);
typedef void (*LHFreeIfAddrsOriginal)(struct ifaddrs *interfaces);
typedef CFDictionaryRef (*LHCFNetworkCopySystemProxySettingsOriginal)(void);
typedef CFDictionaryRef (*LHSCDynamicStoreCopyProxiesOriginal)(void *store);
typedef CFDictionaryRef (*LHSCDynamicStoreCopyProxiesWithOptionsOriginal)(void *store, CFDictionaryRef options);
typedef const char *(*LHNwInterfaceGetNameOriginal)(nw_interface_t interface);
typedef nw_interface_type_t (*LHNwInterfaceGetTypeOriginal)(nw_interface_t interface);
typedef bool (*LHNwPathUsesInterfaceTypeOriginal)(nw_path_t path, nw_interface_type_t interfaceType);
typedef bool (*LHNwPathBooleanOriginal)(nw_path_t path);
typedef bool (^LHNWPathEnumerateInterfacesBlock)(nw_interface_t interface);
typedef void (*LHNwPathEnumerateInterfacesOriginal)(nw_path_t path, LHNWPathEnumerateInterfacesBlock block);

LH_POLICY_SEED(network_interface_ipv4_host)
LH_POLICY_SEED(network_interface_ipv6_suffix)
LH_POLICY_SEED(network_interface_link_mac)
LH_POLICY_SEED(network_interface_counter_profile)

static LHGetIfAddrsOriginal LHInterfaceInventoryGetIfAddrsOriginalImplementation;
static LHFreeIfAddrsOriginal LHInterfaceInventoryFreeIfAddrsOriginalImplementation;
static LHCFNetworkCopySystemProxySettingsOriginal LHInterfaceInventoryCFNetworkCopySystemProxySettingsOriginalImplementation;
static LHSCDynamicStoreCopyProxiesOriginal LHInterfaceInventorySCDynamicStoreCopyProxiesOriginalImplementation;
static LHSCDynamicStoreCopyProxiesWithOptionsOriginal LHInterfaceInventorySCDynamicStoreCopyProxiesWithOptionsOriginalImplementation;
static LHNwInterfaceGetNameOriginal LHInterfaceInventoryNwInterfaceGetNameOriginalImplementation;
static LHNwInterfaceGetTypeOriginal LHInterfaceInventoryNwInterfaceGetTypeOriginalImplementation;
static LHNwPathUsesInterfaceTypeOriginal LHInterfaceInventoryNwPathUsesInterfaceTypeOriginalImplementation;
static LHNwPathBooleanOriginal LHInterfaceInventoryNwPathIsExpensiveOriginalImplementation;
static LHNwPathBooleanOriginal LHInterfaceInventoryNwPathIsConstrainedOriginalImplementation;
static LHNwPathEnumerateInterfacesOriginal LHInterfaceInventoryNwPathEnumerateInterfacesOriginalImplementation;
static LHPolicyEngine *LHInterfaceInventoryPolicy;
static struct ifaddrs *LHInterfaceInventoryOwnedLists[64];

static bool LHInterfaceInventoryNameLooksSensitive(const char *name) {
    if (name == 0) {
        return false;
    }
    return strncmp(name, "tap", 3) == 0 ||
           strncmp(name, "tun", 3) == 0 ||
           strncmp(name, "utun", 4) == 0 ||
           strncmp(name, "ppp", 3) == 0 ||
           strncmp(name, "ipsec", 5) == 0;
}

static bool LHInterfaceInventoryStringContainsSensitiveToken(CFStringRef key) {
    if (key == 0) {
        return false;
    }

    CFStringRef lowercase = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, key);
    if (lowercase == 0) {
        return false;
    }
    CFStringLowercase((CFMutableStringRef)lowercase, 0);

    bool matches = CFStringFind(lowercase, CFSTR("tap"), 0).location != kCFNotFound ||
                   CFStringFind(lowercase, CFSTR("tun"), 0).location != kCFNotFound ||
                   CFStringFind(lowercase, CFSTR("utun"), 0).location != kCFNotFound ||
                   CFStringFind(lowercase, CFSTR("ppp"), 0).location != kCFNotFound ||
                   CFStringFind(lowercase, CFSTR("ipsec"), 0).location != kCFNotFound;
    CFRelease(lowercase);
    return matches;
}

static bool LHInterfaceInventoryPathTypeLooksSensitive(nw_interface_type_t type) {
    return type == nw_interface_type_other || type == nw_interface_type_loopback;
}

static const char *LHInterfaceInventoryCommonNetworkInterfaceName(nw_interface_type_t type) {
    switch (type) {
        case nw_interface_type_cellular:
            return "pdp_ip0";
        case nw_interface_type_wifi:
        case nw_interface_type_wired:
        case nw_interface_type_other:
        case nw_interface_type_loopback:
        default:
            return "en0";
    }
}

static bool LHInterfaceInventoryNameLooksLoopback(const char *name) {
    return name != 0 && strncmp(name, "lo", 2) == 0;
}

static bool LHInterfaceInventoryDeriveBytes(const LHPolicySeed *policySeed,
                                            const char *name,
                                            uint8_t *output,
                                            size_t outputLength) {
    if (LHInterfaceInventoryPolicy == 0 || policySeed == 0 || output == 0 || outputLength == 0) {
        return false;
    }
    const uint8_t *context = name == 0 ? 0 : (const uint8_t *)name;
    size_t contextLength = name == 0 ? 0 : strlen(name);
    return LHMitigationDeriveBytes(&LHInterfaceInventoryPolicy->config.buildSeed,
                                   policySeed,
                                   &LHInterfaceInventoryPolicy->appContext.scope,
                                   context,
                                   contextLength,
                                   output,
                                   outputLength);
}

static void LHInterfaceInventoryRewriteIPv4(struct ifaddrs *entry) {
    if (entry == 0 || entry->ifa_addr == 0 || LHInterfaceInventoryNameLooksLoopback(entry->ifa_name)) {
        return;
    }

    uint8_t byte = 0;
    if (!LHInterfaceInventoryDeriveBytes(&LHGeneratedPolicySeed_network_interface_ipv4_host,
                                         entry->ifa_name,
                                         &byte,
                                         sizeof(byte))) {
        return;
    }

    uint32_t host = 20U + ((uint32_t)byte % 180U);
    struct sockaddr_in *address = (struct sockaddr_in *)entry->ifa_addr;
    address->sin_addr.s_addr = htonl(0xC0A80100U | host);

    if (entry->ifa_netmask != 0 && entry->ifa_netmask->sa_family == AF_INET) {
        struct sockaddr_in *netmask = (struct sockaddr_in *)entry->ifa_netmask;
        netmask->sin_addr.s_addr = htonl(0xFFFFFF00U);
    }
    if (entry->ifa_dstaddr != 0 && entry->ifa_dstaddr->sa_family == AF_INET) {
        struct sockaddr_in *destination = (struct sockaddr_in *)entry->ifa_dstaddr;
        destination->sin_addr.s_addr = htonl(0xC0A801FFU);
    }
}

static void LHInterfaceInventoryRewriteIPv6(struct ifaddrs *entry) {
    if (entry == 0 || entry->ifa_addr == 0 || LHInterfaceInventoryNameLooksLoopback(entry->ifa_name)) {
        return;
    }

    uint8_t bytes[8] = { 0 };
    if (!LHInterfaceInventoryDeriveBytes(&LHGeneratedPolicySeed_network_interface_ipv6_suffix,
                                         entry->ifa_name,
                                         bytes,
                                         sizeof(bytes))) {
        return;
    }

    struct sockaddr_in6 *address = (struct sockaddr_in6 *)entry->ifa_addr;
    memset(&address->sin6_addr, 0, sizeof(address->sin6_addr));
    address->sin6_addr.s6_addr[0] = 0xfe;
    address->sin6_addr.s6_addr[1] = 0x80;
    memcpy(&address->sin6_addr.s6_addr[8], bytes, sizeof(bytes));

    if (entry->ifa_netmask != 0 && entry->ifa_netmask->sa_family == AF_INET6) {
        struct sockaddr_in6 *netmask = (struct sockaddr_in6 *)entry->ifa_netmask;
        memset(&netmask->sin6_addr, 0, sizeof(netmask->sin6_addr));
        memset(&netmask->sin6_addr.s6_addr[0], 0xff, 8);
    }
    if (entry->ifa_dstaddr != 0 && entry->ifa_dstaddr->sa_family == AF_INET6) {
        struct sockaddr_in6 *destination = (struct sockaddr_in6 *)entry->ifa_dstaddr;
        memset(&destination->sin6_addr, 0, sizeof(destination->sin6_addr));
        destination->sin6_addr.s6_addr[0] = 0xfe;
        destination->sin6_addr.s6_addr[1] = 0x80;
        memset(&destination->sin6_addr.s6_addr[8], 0xff, 8);
    }
}

static void LHInterfaceInventoryRewriteLinkAddress(struct ifaddrs *entry) {
    if (entry == 0 || entry->ifa_addr == 0 || LHInterfaceInventoryNameLooksLoopback(entry->ifa_name)) {
        return;
    }

    struct sockaddr_dl *link = (struct sockaddr_dl *)entry->ifa_addr;
    if (link->sdl_alen < 6) {
        return;
    }

    uint8_t bytes[6] = { 0 };
    if (!LHInterfaceInventoryDeriveBytes(&LHGeneratedPolicySeed_network_interface_link_mac,
                                         entry->ifa_name,
                                         bytes,
                                         sizeof(bytes))) {
        return;
    }
    bytes[0] = (uint8_t)((bytes[0] | 0x02) & 0xfe);
    memcpy(LLADDR(link), bytes, sizeof(bytes));
}

static void LHInterfaceInventoryRewriteEntry(struct ifaddrs *entry) {
    if (entry == 0 || entry->ifa_addr == 0) {
        return;
    }

    if (LHInterfaceInventoryNameLooksSensitive(entry->ifa_name)) {
        entry->ifa_flags &= ~(IFF_UP | IFF_RUNNING);
    }

    switch (entry->ifa_addr->sa_family) {
        case AF_INET:
            LHInterfaceInventoryRewriteIPv4(entry);
            break;
        case AF_INET6:
            LHInterfaceInventoryRewriteIPv6(entry);
            break;
        case AF_LINK:
            LHInterfaceInventoryRewriteLinkAddress(entry);
            break;
        default:
            break;
    }
}

static uint64_t LHInterfaceInventoryUptimeSeconds(void) {
    struct timeval bootTime;
    memset(&bootTime, 0, sizeof(bootTime));
    size_t length = sizeof(bootTime);
    if (sysctlbyname("kern.boottime", &bootTime, &length, 0, 0) != 0 || bootTime.tv_sec <= 0) {
        return 0;
    }

    time_t now = time(0);
    if (now <= bootTime.tv_sec) {
        return 0;
    }
    return (uint64_t)(now - bootTime.tv_sec);
}

static uint64_t LHInterfaceInventoryDeriveCounterBounded(const char *name, const char *field, uint64_t upperBound) {
    if (LHInterfaceInventoryPolicy == 0 || field == 0 || upperBound == 0) {
        return 0;
    }

    char context[96] = { 0 };
    snprintf(context, sizeof(context), "%s:%s", name == 0 ? "" : name, field);
    uint64_t value = 0;
    if (!LHMitigationDeriveBoundedU64(&LHInterfaceInventoryPolicy->config.buildSeed,
                                      &LHGeneratedPolicySeed_network_interface_counter_profile,
                                      &LHInterfaceInventoryPolicy->appContext.scope,
                                      (const uint8_t *)context,
                                      strlen(context),
                                      upperBound,
                                      &value)) {
        return 0;
    }
    return value;
}

static uint32_t LHInterfaceInventoryClampU32(uint64_t value) {
    return value > UINT32_MAX ? UINT32_MAX : (uint32_t)value;
}

static uint32_t LHInterfaceInventorySyntheticBytes(const char *name, const char *field, uint64_t uptimeSeconds) {
    uint64_t base = (16ULL * 1024ULL * 1024ULL) + LHInterfaceInventoryDeriveCounterBounded(name, field, 240ULL * 1024ULL * 1024ULL);
    uint64_t rate = 64ULL + LHInterfaceInventoryDeriveCounterBounded(name, field, 449ULL);
    uint64_t wobble = (uptimeSeconds / 300ULL) * (1ULL + LHInterfaceInventoryDeriveCounterBounded(name, field, 4096ULL));
    return LHInterfaceInventoryClampU32(base + (rate * uptimeSeconds) + wobble);
}

static uint32_t LHInterfaceInventorySyntheticPackets(const char *name, const char *field, uint32_t bytes) {
    uint64_t averagePacket = 720ULL + LHInterfaceInventoryDeriveCounterBounded(name, field, 640ULL);
    return averagePacket == 0 ? bytes : LHInterfaceInventoryClampU32((uint64_t)bytes / averagePacket);
}

static uint32_t LHInterfaceInventoryCommonBaudRate(const char *name, uint32_t original) {
    if (name == 0 || original == 0) {
        return original;
    }
    if (strncmp(name, "lo", 2) == 0) {
        return original;
    }
    if (strncmp(name, "en", 2) == 0) {
        return 1000000000U;
    }
    if (strncmp(name, "pdp_ip", 6) == 0) {
        return 100000000U;
    }
    return 100000000U;
}

static void LHInterfaceInventoryShapeCounterData(struct ifaddrs *interfaces) {
    uint64_t uptimeSeconds = LHInterfaceInventoryUptimeSeconds();
    for (struct ifaddrs *cursor = interfaces; cursor != 0; cursor = cursor->ifa_next) {
        if (cursor->ifa_data == 0) {
            continue;
        }

        struct if_data *data = (struct if_data *)cursor->ifa_data;
        if (!LHInterfaceInventoryNameLooksLoopback(cursor->ifa_name)) {
            data->ifi_ibytes = LHInterfaceInventorySyntheticBytes(cursor->ifa_name, "ibytes", uptimeSeconds);
            data->ifi_obytes = LHInterfaceInventorySyntheticBytes(cursor->ifa_name, "obytes", uptimeSeconds);
            data->ifi_ipackets = LHInterfaceInventorySyntheticPackets(cursor->ifa_name, "ipackets", data->ifi_ibytes);
            data->ifi_opackets = LHInterfaceInventorySyntheticPackets(cursor->ifa_name, "opackets", data->ifi_obytes);
        }
        data->ifi_ierrors = (uint32_t)LHInterfaceInventoryDeriveCounterBounded(cursor->ifa_name, "ierrors", 3);
        data->ifi_oerrors = (uint32_t)LHInterfaceInventoryDeriveCounterBounded(cursor->ifa_name, "oerrors", 3);
        data->ifi_collisions = 0;
        data->ifi_baudrate = LHInterfaceInventoryCommonBaudRate(cursor->ifa_name, data->ifi_baudrate);
        data->ifi_lastchange.tv_sec = uptimeSeconds == 0 ? 0 : time(0) - (time_t)uptimeSeconds;
        data->ifi_lastchange.tv_usec = 0;
    }
}

static CFDictionaryRef LHInterfaceInventoryFilterScopedProxySettings(CFDictionaryRef original) {
    if (original == 0) {
        return 0;
    }

    CFTypeRef scopedValue = CFDictionaryGetValue(original, CFSTR("__SCOPED__"));
    if (scopedValue == 0 || CFGetTypeID(scopedValue) != CFDictionaryGetTypeID()) {
        return (CFDictionaryRef)CFRetain(original);
    }

    CFDictionaryRef scoped = (CFDictionaryRef)scopedValue;
    CFMutableDictionaryRef filteredScoped = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, scoped);
    if (filteredScoped == 0) {
        return (CFDictionaryRef)CFRetain(original);
    }

    CFIndex count = CFDictionaryGetCount(scoped);
    const void **keys = 0;
    if (count > 0) {
        keys = (const void **)calloc((size_t)count, sizeof(void *));
    }
    if (count > 0 && keys == 0) {
        CFRelease(filteredScoped);
        return (CFDictionaryRef)CFRetain(original);
    }

    CFDictionaryGetKeysAndValues(scoped, keys, 0);
    bool removed = false;
    for (CFIndex index = 0; index < count; index++) {
        CFTypeRef key = keys[index];
        if (key != 0 && CFGetTypeID(key) == CFStringGetTypeID() && LHInterfaceInventoryStringContainsSensitiveToken((CFStringRef)key)) {
            CFDictionaryRemoveValue(filteredScoped, key);
            removed = true;
        }
    }
    free(keys);

    if (!removed) {
        CFRelease(filteredScoped);
        return (CFDictionaryRef)CFRetain(original);
    }

    CFMutableDictionaryRef filtered = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, original);
    if (filtered == 0) {
        CFRelease(filteredScoped);
        return (CFDictionaryRef)CFRetain(original);
    }

    CFDictionarySetValue(filtered, CFSTR("__SCOPED__"), filteredScoped);
    CFRelease(filteredScoped);
    return filtered;
}

static CFDictionaryRef LHInterfaceInventoryCopyFilteredProxySettings(CFDictionaryRef original) {
    CFDictionaryRef filtered = LHInterfaceInventoryFilterScopedProxySettings(original);
    if (original != 0) {
        CFRelease(original);
    }
    return filtered;
}

static size_t LHInterfaceInventorySockaddrLength(const struct sockaddr *address) {
    if (address == 0) {
        return 0;
    }
    if (address->sa_len != 0) {
        return address->sa_len;
    }
    switch (address->sa_family) {
        case AF_INET:
            return sizeof(struct sockaddr_in);
        case AF_INET6:
            return sizeof(struct sockaddr_in6);
        case AF_LINK:
            return sizeof(struct sockaddr_dl);
        default:
            return sizeof(struct sockaddr);
    }
}

static struct sockaddr *LHInterfaceInventoryCopySockaddr(const struct sockaddr *address) {
    size_t length = LHInterfaceInventorySockaddrLength(address);
    if (length == 0) {
        return 0;
    }
    struct sockaddr *copy = (struct sockaddr *)malloc(length);
    if (copy == 0) {
        return 0;
    }
    memcpy(copy, address, length);
    return copy;
}

static void *LHInterfaceInventoryCopyData(const void *data) {
    if (data == 0) {
        return 0;
    }
    void *copy = malloc(sizeof(struct if_data));
    if (copy == 0) {
        return 0;
    }
    memcpy(copy, data, sizeof(struct if_data));
    return copy;
}

static void LHInterfaceInventoryFreeOwnedList(struct ifaddrs *interfaces) {
    struct ifaddrs *cursor = interfaces;
    while (cursor != 0) {
        struct ifaddrs *next = cursor->ifa_next;
        free(cursor->ifa_name);
        free(cursor->ifa_addr);
        free(cursor->ifa_netmask);
        free(cursor->ifa_dstaddr);
        free(cursor->ifa_data);
        free(cursor);
        cursor = next;
    }
}

static bool LHInterfaceInventoryRememberOwnedList(struct ifaddrs *interfaces) {
    if (interfaces == 0) {
        return false;
    }
    for (size_t index = 0; index < sizeof(LHInterfaceInventoryOwnedLists) / sizeof(LHInterfaceInventoryOwnedLists[0]); index++) {
        if (LHInterfaceInventoryOwnedLists[index] == 0) {
            LHInterfaceInventoryOwnedLists[index] = interfaces;
            return true;
        }
    }
    return false;
}

static bool LHInterfaceInventoryForgetOwnedList(struct ifaddrs *interfaces) {
    for (size_t index = 0; index < sizeof(LHInterfaceInventoryOwnedLists) / sizeof(LHInterfaceInventoryOwnedLists[0]); index++) {
        if (LHInterfaceInventoryOwnedLists[index] == interfaces) {
            LHInterfaceInventoryOwnedLists[index] = 0;
            return true;
        }
    }
    return false;
}

static struct ifaddrs *LHInterfaceInventoryCloneVisibleList(struct ifaddrs *interfaces, bool *filtered, bool *failed) {
    struct ifaddrs *head = 0;
    struct ifaddrs *tail = 0;
    if (filtered != 0) {
        *filtered = false;
    }
    if (failed != 0) {
        *failed = false;
    }

    for (struct ifaddrs *cursor = interfaces; cursor != 0; cursor = cursor->ifa_next) {
        if (LHInterfaceInventoryNameLooksSensitive(cursor->ifa_name)) {
            if (filtered != 0) {
                *filtered = true;
            }
            continue;
        }

        struct ifaddrs *copy = (struct ifaddrs *)calloc(1, sizeof(struct ifaddrs));
        if (copy == 0) {
            LHInterfaceInventoryFreeOwnedList(head);
            if (failed != 0) {
                *failed = true;
            }
            return 0;
        }
        *copy = *cursor;
        copy->ifa_next = 0;
        copy->ifa_name = cursor->ifa_name == 0 ? 0 : strdup(cursor->ifa_name);
        copy->ifa_addr = LHInterfaceInventoryCopySockaddr(cursor->ifa_addr);
        copy->ifa_netmask = LHInterfaceInventoryCopySockaddr(cursor->ifa_netmask);
        copy->ifa_dstaddr = LHInterfaceInventoryCopySockaddr(cursor->ifa_dstaddr);
        copy->ifa_data = LHInterfaceInventoryCopyData(cursor->ifa_data);

        if ((cursor->ifa_name != 0 && copy->ifa_name == 0) ||
            (cursor->ifa_addr != 0 && copy->ifa_addr == 0) ||
            (cursor->ifa_netmask != 0 && copy->ifa_netmask == 0) ||
            (cursor->ifa_dstaddr != 0 && copy->ifa_dstaddr == 0) ||
            (cursor->ifa_data != 0 && copy->ifa_data == 0)) {
            LHInterfaceInventoryFreeOwnedList(copy);
            LHInterfaceInventoryFreeOwnedList(head);
            if (failed != 0) {
                *failed = true;
            }
            return 0;
        }

        if (tail == 0) {
            head = copy;
        } else {
            tail->ifa_next = copy;
        }
        tail = copy;
    }
    return head;
}

static int LHInterfaceInventoryGetIfAddrsReplacement(struct ifaddrs **interfaces) {
    if (LHInterfaceInventoryGetIfAddrsOriginalImplementation == 0) {
        return -1;
    }

    int result = LHInterfaceInventoryGetIfAddrsOriginalImplementation(interfaces);
    if (result != 0 || interfaces == 0 || *interfaces == 0) {
        return result;
    }

    bool filtered = false;
    bool failed = false;
    struct ifaddrs *visible = LHInterfaceInventoryCloneVisibleList(*interfaces, &filtered, &failed);
    if (filtered && !failed && (visible == 0 || LHInterfaceInventoryRememberOwnedList(visible))) {
        if (LHInterfaceInventoryFreeIfAddrsOriginalImplementation != 0) {
            LHInterfaceInventoryFreeIfAddrsOriginalImplementation(*interfaces);
        }
        *interfaces = visible;
    } else {
        LHInterfaceInventoryFreeOwnedList(visible);
    }

    for (struct ifaddrs *cursor = *interfaces; cursor != 0; cursor = cursor->ifa_next) {
        LHInterfaceInventoryRewriteEntry(cursor);
    }
    LHInterfaceInventoryShapeCounterData(*interfaces);
    return result;
}

static void LHInterfaceInventoryFreeIfAddrsReplacement(struct ifaddrs *interfaces) {
    if (interfaces != 0 && LHInterfaceInventoryForgetOwnedList(interfaces)) {
        LHInterfaceInventoryFreeOwnedList(interfaces);
        return;
    }
    if (LHInterfaceInventoryFreeIfAddrsOriginalImplementation != 0) {
        LHInterfaceInventoryFreeIfAddrsOriginalImplementation(interfaces);
    }
}

static CFDictionaryRef LHInterfaceInventoryCFNetworkCopySystemProxySettingsReplacement(void) {
    if (LHInterfaceInventoryCFNetworkCopySystemProxySettingsOriginalImplementation == 0) {
        return 0;
    }

    return LHInterfaceInventoryCopyFilteredProxySettings(LHInterfaceInventoryCFNetworkCopySystemProxySettingsOriginalImplementation());
}

static CFDictionaryRef LHInterfaceInventorySCDynamicStoreCopyProxiesReplacement(void *store) {
    if (LHInterfaceInventorySCDynamicStoreCopyProxiesOriginalImplementation == 0) {
        return 0;
    }

    return LHInterfaceInventoryCopyFilteredProxySettings(LHInterfaceInventorySCDynamicStoreCopyProxiesOriginalImplementation(store));
}

static CFDictionaryRef LHInterfaceInventorySCDynamicStoreCopyProxiesWithOptionsReplacement(void *store, CFDictionaryRef options) {
    if (LHInterfaceInventorySCDynamicStoreCopyProxiesWithOptionsOriginalImplementation == 0) {
        return 0;
    }

    return LHInterfaceInventoryCopyFilteredProxySettings(LHInterfaceInventorySCDynamicStoreCopyProxiesWithOptionsOriginalImplementation(store, options));
}

static const char *LHInterfaceInventoryNwInterfaceGetNameReplacement(nw_interface_t interface) {
    if (LHInterfaceInventoryNwInterfaceGetNameOriginalImplementation == 0) {
        return "en0";
    }

    const char *name = LHInterfaceInventoryNwInterfaceGetNameOriginalImplementation(interface);
    nw_interface_type_t type = nw_interface_type_other;
    if (LHInterfaceInventoryNwInterfaceGetTypeOriginalImplementation != 0) {
        type = LHInterfaceInventoryNwInterfaceGetTypeOriginalImplementation(interface);
    }
    if (LHInterfaceInventoryNameLooksSensitive(name) || LHInterfaceInventoryPathTypeLooksSensitive(type)) {
        return LHInterfaceInventoryCommonNetworkInterfaceName(type);
    }
    return name;
}

static nw_interface_type_t LHInterfaceInventoryNwInterfaceGetTypeReplacement(nw_interface_t interface) {
    if (LHInterfaceInventoryNwInterfaceGetTypeOriginalImplementation == 0) {
        return nw_interface_type_wifi;
    }

    nw_interface_type_t original = LHInterfaceInventoryNwInterfaceGetTypeOriginalImplementation(interface);
    if (LHInterfaceInventoryPathTypeLooksSensitive(original)) {
        return nw_interface_type_wifi;
    }
    return original;
}

static bool LHInterfaceInventoryNwPathUsesInterfaceTypeReplacement(nw_path_t path, nw_interface_type_t interfaceType) {
    if (LHInterfaceInventoryPathTypeLooksSensitive(interfaceType)) {
        return false;
    }
    if (LHInterfaceInventoryNwPathUsesInterfaceTypeOriginalImplementation == 0) {
        return false;
    }
    return LHInterfaceInventoryNwPathUsesInterfaceTypeOriginalImplementation(path, interfaceType);
}

static bool LHInterfaceInventoryNwPathIsExpensiveReplacement(nw_path_t path) {
    if (LHInterfaceInventoryNwPathIsExpensiveOriginalImplementation == 0) {
        return false;
    }
    return LHInterfaceInventoryNwPathIsExpensiveOriginalImplementation(path);
}

static bool LHInterfaceInventoryNwPathIsConstrainedReplacement(nw_path_t path) {
    if (LHInterfaceInventoryNwPathIsConstrainedOriginalImplementation == 0) {
        return false;
    }
    return LHInterfaceInventoryNwPathIsConstrainedOriginalImplementation(path);
}

static void LHInterfaceInventoryNwPathEnumerateInterfacesReplacement(nw_path_t path, LHNWPathEnumerateInterfacesBlock block) {
    if (LHInterfaceInventoryNwPathEnumerateInterfacesOriginalImplementation == 0 || block == 0) {
        return;
    }

    LHInterfaceInventoryNwPathEnumerateInterfacesOriginalImplementation(path, ^bool(nw_interface_t interface) {
        if (LHInterfaceInventoryNwInterfaceGetTypeOriginalImplementation != 0 &&
            LHInterfaceInventoryPathTypeLooksSensitive(LHInterfaceInventoryNwInterfaceGetTypeOriginalImplementation(interface))) {
            return true;
        }
        return block(interface);
    });
}

static bool LHInterfaceInventoryHookFunction(LHHookBackend *backend, const char *symbol, void *replacement, void **original) {
    bool installed = false;
    void *target = dlsym(RTLD_DEFAULT, symbol);
    if (target != 0) {
        installed = LHHookBackendHookFunction(backend, target, replacement, original) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend, symbol, replacement, original) || installed;
    return installed;
}

bool LHMitigation_network_interface_inventory_composite_common_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHInterfaceInventoryPolicy = policy;

    bool installed = false;
    void *target = dlsym(RTLD_DEFAULT, "getifaddrs");
    if (target != 0) {
        installed = LHHookBackendHookFunction(backend,
                                              target,
                                              (void *)LHInterfaceInventoryGetIfAddrsReplacement,
                                              (void **)&LHInterfaceInventoryGetIfAddrsOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "getifaddrs",
                                                (void *)LHInterfaceInventoryGetIfAddrsReplacement,
                                                (void **)&LHInterfaceInventoryGetIfAddrsOriginalImplementation) || installed;
    void *freeTarget = dlsym(RTLD_DEFAULT, "freeifaddrs");
    if (freeTarget != 0) {
        installed = LHHookBackendHookFunction(backend,
                                              freeTarget,
                                              (void *)LHInterfaceInventoryFreeIfAddrsReplacement,
                                              (void **)&LHInterfaceInventoryFreeIfAddrsOriginalImplementation) || installed;
    }
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "freeifaddrs",
                                                (void *)LHInterfaceInventoryFreeIfAddrsReplacement,
                                                (void **)&LHInterfaceInventoryFreeIfAddrsOriginalImplementation) || installed;
    installed = LHInterfaceInventoryHookFunction(backend,
                                                 "CFNetworkCopySystemProxySettings",
                                                 (void *)LHInterfaceInventoryCFNetworkCopySystemProxySettingsReplacement,
                                                 (void **)&LHInterfaceInventoryCFNetworkCopySystemProxySettingsOriginalImplementation) || installed;
    installed = LHInterfaceInventoryHookFunction(backend,
                                                 "SCDynamicStoreCopyProxies",
                                                 (void *)LHInterfaceInventorySCDynamicStoreCopyProxiesReplacement,
                                                 (void **)&LHInterfaceInventorySCDynamicStoreCopyProxiesOriginalImplementation) || installed;
    installed = LHInterfaceInventoryHookFunction(backend,
                                                 "SCDynamicStoreCopyProxiesWithOptions",
                                                 (void *)LHInterfaceInventorySCDynamicStoreCopyProxiesWithOptionsReplacement,
                                                 (void **)&LHInterfaceInventorySCDynamicStoreCopyProxiesWithOptionsOriginalImplementation) || installed;
    installed = LHInterfaceInventoryHookFunction(backend,
                                                 "nw_interface_get_name",
                                                 (void *)LHInterfaceInventoryNwInterfaceGetNameReplacement,
                                                 (void **)&LHInterfaceInventoryNwInterfaceGetNameOriginalImplementation) || installed;
    installed = LHInterfaceInventoryHookFunction(backend,
                                                 "nw_interface_get_type",
                                                 (void *)LHInterfaceInventoryNwInterfaceGetTypeReplacement,
                                                 (void **)&LHInterfaceInventoryNwInterfaceGetTypeOriginalImplementation) || installed;
    installed = LHInterfaceInventoryHookFunction(backend,
                                                 "nw_path_uses_interface_type",
                                                 (void *)LHInterfaceInventoryNwPathUsesInterfaceTypeReplacement,
                                                 (void **)&LHInterfaceInventoryNwPathUsesInterfaceTypeOriginalImplementation) || installed;
    installed = LHInterfaceInventoryHookFunction(backend,
                                                 "nw_path_is_expensive",
                                                 (void *)LHInterfaceInventoryNwPathIsExpensiveReplacement,
                                                 (void **)&LHInterfaceInventoryNwPathIsExpensiveOriginalImplementation) || installed;
    installed = LHInterfaceInventoryHookFunction(backend,
                                                 "nw_path_is_constrained",
                                                 (void *)LHInterfaceInventoryNwPathIsConstrainedReplacement,
                                                 (void **)&LHInterfaceInventoryNwPathIsConstrainedOriginalImplementation) || installed;
    installed = LHInterfaceInventoryHookFunction(backend,
                                                 "nw_path_enumerate_interfaces",
                                                 (void *)LHInterfaceInventoryNwPathEnumerateInterfacesReplacement,
                                                 (void **)&LHInterfaceInventoryNwPathEnumerateInterfacesOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_network_interface_inventory_composite_common);
    }
    return true;
}
