#include "LHModuleRegistry.h"
#include "LHGeneratedMitigationRegistry.h"

#include "LHMitigationValues.h"
#include "InterfaceTrafficMitigation.h"
#include "RoutingTableMitigation.h"

#include <arpa/inet.h>
#include <CoreFoundation/CoreFoundation.h>
#include <errno.h>
#include <ifaddrs.h>
#include <Network/Network.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <net/if_var.h>
#include <netinet/in.h>
#include <stddef.h>
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
typedef struct if_nameindex *(*LHIfNameIndexOriginal)(void);
typedef char *(*LHIfIndexToNameOriginal)(unsigned int interfaceIndex, char *interfaceName);
typedef unsigned int (*LHIfNameToIndexOriginal)(const char *interfaceName);
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
LH_POLICY_SEED(network_interface_name_alias)

static LHGetIfAddrsOriginal LHInterfaceInventoryGetIfAddrsOriginalImplementation;
static LHIfNameIndexOriginal LHInterfaceInventoryIfNameIndexOriginalImplementation;
static LHIfIndexToNameOriginal LHInterfaceInventoryIfIndexToNameOriginalImplementation;
static LHIfNameToIndexOriginal LHInterfaceInventoryIfNameToIndexOriginalImplementation;
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

static const char *LHInterfaceInventoryCommonAliasForName(const char *name);

static const char *LHInterfaceInventoryCommonNetworkInterfaceName(nw_interface_type_t type, const char *name) {
    if (LHInterfaceInventoryNameLooksSensitive(name)) {
        return LHInterfaceInventoryCommonAliasForName(name);
    }

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

static const char *LHInterfaceInventoryCommonAliasForName(const char *name) {
    static const char *const aliases[] = { "en1", "en2", "en3" };
    uint8_t byte = 0;
    if (!LHInterfaceInventoryDeriveBytes(&LHGeneratedPolicySeed_network_interface_name_alias,
                                         name,
                                         &byte,
                                         sizeof(byte))) {
        return "en0";
    }
    return aliases[byte % (sizeof(aliases) / sizeof(aliases[0]))];
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
    if (LHInterfaceInventoryNameLooksSensitive(entry->ifa_name)) {
        address->sin6_scope_id = 0;
    }

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
        if (LHInterfaceInventoryNameLooksSensitive(entry->ifa_name)) {
            destination->sin6_scope_id = 0;
        }
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

void LHInterfaceInventoryRewriteEntry(struct ifaddrs *entry) {
    if (entry == 0) {
        return;
    }

    if (LHInterfaceInventoryNameLooksSensitive(entry->ifa_name)) {
        entry->ifa_flags &= ~(IFF_UP | IFF_RUNNING);
    }

    if (entry->ifa_addr == 0) {
        return;
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

static void LHInterfaceInventoryRewriteLinkName(struct ifaddrs *entry) {
    if (entry == 0 || entry->ifa_addr == 0 || entry->ifa_addr->sa_family != AF_LINK ||
        !LHInterfaceInventoryNameLooksSensitive(entry->ifa_name)) {
        return;
    }

    const char *alias = LHInterfaceInventoryCommonAliasForName(entry->ifa_name);
    size_t aliasLength = strlen(alias);
    struct sockaddr_dl *link = (struct sockaddr_dl *)entry->ifa_addr;
    size_t dataOffset = offsetof(struct sockaddr_dl, sdl_data);
    if (link->sdl_len <= dataOffset) {
        return;
    }

    size_t capacity = (size_t)link->sdl_len - dataOffset;
    size_t originalNameLength = link->sdl_nlen;
    size_t tailLength = (size_t)link->sdl_alen + (size_t)link->sdl_slen;
    if (originalNameLength > capacity || tailLength > capacity - originalNameLength ||
        aliasLength > capacity || tailLength > capacity - aliasLength) {
        return;
    }

    uint8_t *data = (uint8_t *)link->sdl_data;
    memmove(data + aliasLength, data + originalNameLength, tailLength);
    if (originalNameLength > aliasLength) {
        memset(data + aliasLength + tailLength, 0, originalNameLength - aliasLength);
    }
    memcpy(data, alias, aliasLength);
    link->sdl_nlen = (uint8_t)aliasLength;
}

static void LHInterfaceInventoryRewriteInterfaceName(struct ifaddrs *entry) {
    if (entry == 0 || !LHInterfaceInventoryNameLooksSensitive(entry->ifa_name)) {
        return;
    }

    const char *alias = LHInterfaceInventoryCommonAliasForName(entry->ifa_name);
    size_t aliasLength = strlen(alias);
    if (strlen(entry->ifa_name) < aliasLength) {
        return;
    }
    memcpy(entry->ifa_name, alias, aliasLength + 1);
}

static void LHInterfaceInventoryRewriteSensitiveNames(struct ifaddrs *interfaces) {
    for (struct ifaddrs *cursor = interfaces; cursor != 0; cursor = cursor->ifa_next) {
        LHInterfaceInventoryRewriteLinkName(cursor);
    }
    for (struct ifaddrs *cursor = interfaces; cursor != 0; cursor = cursor->ifa_next) {
        LHInterfaceInventoryRewriteInterfaceName(cursor);
    }
}

void LHInterfaceInventoryRewriteSensitiveEntryName(struct ifaddrs *entry) {
    LHInterfaceInventoryRewriteLinkName(entry);
    LHInterfaceInventoryRewriteInterfaceName(entry);
}

static void LHInterfaceInventoryShapeCounterData(struct ifaddrs *interfaces) {
    LHInterfaceTrafficSnapshot snapshot;
    if (!LHInterfaceTrafficCopySnapshot(&snapshot)) {
        return;
    }
    for (struct ifaddrs *cursor = interfaces; cursor != 0; cursor = cursor->ifa_next) {
        if (cursor->ifa_data == 0 || cursor->ifa_addr == 0 || cursor->ifa_addr->sa_family != AF_LINK ||
            cursor->ifa_name == 0 || LHInterfaceInventoryNameLooksLoopback(cursor->ifa_name)) {
            continue;
        }
        LHInterfaceTrafficValues values;
        if (LHInterfaceTrafficCopyValues(LHInterfaceInventoryPolicy, cursor->ifa_name, &snapshot, &values)) {
            LHInterfaceTrafficApply32((struct if_data *)cursor->ifa_data, cursor->ifa_name, &snapshot, &values);
        }
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

static int LHInterfaceInventoryGetIfAddrsReplacement(struct ifaddrs **interfaces) {
    if (LHInterfaceInventoryGetIfAddrsOriginalImplementation == 0) {
        errno = ENOSYS;
        return -1;
    }

    LHInterfaceTrafficBeginOriginalList();
    int result = LHInterfaceInventoryGetIfAddrsOriginalImplementation(interfaces);
    LHInterfaceTrafficEndOriginalList();
    if (result != 0 || interfaces == 0 || *interfaces == 0) {
        return result;
    }
    int originalErrno = errno;

    for (struct ifaddrs *cursor = *interfaces; cursor != 0; cursor = cursor->ifa_next) {
        LHInterfaceInventoryRewriteEntry(cursor);
    }
    LHInterfaceInventoryShapeCounterData(*interfaces);
    LHInterfaceInventoryRewriteSensitiveNames(*interfaces);
    errno = originalErrno;
    return result;
}

static struct if_nameindex *LHInterfaceInventoryIfNameIndexReplacement(void) {
    if (LHInterfaceInventoryIfNameIndexOriginalImplementation == 0) {
        return 0;
    }

    struct if_nameindex *interfaces = LHInterfaceInventoryIfNameIndexOriginalImplementation();
    if (interfaces == 0) {
        return 0;
    }

    for (struct if_nameindex *cursor = interfaces; cursor->if_index != 0 || cursor->if_name != 0; cursor++) {
        if (!LHInterfaceInventoryNameLooksSensitive(cursor->if_name)) {
            continue;
        }
        const char *alias = LHInterfaceInventoryCommonAliasForName(cursor->if_name);
        size_t aliasLength = strlen(alias);
        if (strlen(cursor->if_name) >= aliasLength) {
            memcpy(cursor->if_name, alias, aliasLength + 1);
        }
    }
    return interfaces;
}

static char *LHInterfaceInventoryIfIndexToNameReplacement(unsigned int interfaceIndex, char *interfaceName) {
    if (LHInterfaceInventoryIfIndexToNameOriginalImplementation == 0) {
        return 0;
    }

    char *result = LHInterfaceInventoryIfIndexToNameOriginalImplementation(interfaceIndex, interfaceName);
    if (result == 0 || !LHInterfaceInventoryNameLooksSensitive(result)) {
        return result;
    }

    const char *alias = LHInterfaceInventoryCommonAliasForName(result);
    size_t aliasLength = strlen(alias);
    if (aliasLength >= IFNAMSIZ) {
        return result;
    }
    memcpy(result, alias, aliasLength + 1);
    return result;
}

static unsigned int LHInterfaceInventoryIfNameToIndexReplacement(const char *interfaceName) {
    if (LHInterfaceInventoryNameLooksSensitive(interfaceName)) {
        errno = ENXIO;
        return 0;
    }
    if (LHInterfaceInventoryIfNameToIndexOriginalImplementation == 0) {
        return 0;
    }
    return LHInterfaceInventoryIfNameToIndexOriginalImplementation(interfaceName);
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
        return LHInterfaceInventoryCommonNetworkInterfaceName(type, name);
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

bool LHMitigation_network_interface_inventory_composite_common_install(LHHookBackend *backend, LHPolicyEngine *policy) {
    LHInterfaceInventoryPolicy = policy;

    bool installed = LHInterfaceInventoryInstallTrafficHooks(backend, policy);
    installed = LHInterfaceInventoryInstallRoutingHooks(backend, policy) || installed;
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "getifaddrs",
                                                (void *)LHInterfaceInventoryGetIfAddrsReplacement,
                                                (void **)&LHInterfaceInventoryGetIfAddrsOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "if_nameindex",
                                                (void *)LHInterfaceInventoryIfNameIndexReplacement,
                                                (void **)&LHInterfaceInventoryIfNameIndexOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "if_indextoname",
                                                (void *)LHInterfaceInventoryIfIndexToNameReplacement,
                                                (void **)&LHInterfaceInventoryIfIndexToNameOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "if_nametoindex",
                                                (void *)LHInterfaceInventoryIfNameToIndexReplacement,
                                                (void **)&LHInterfaceInventoryIfNameToIndexOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "CFNetworkCopySystemProxySettings",
                                                (void *)LHInterfaceInventoryCFNetworkCopySystemProxySettingsReplacement,
                                                (void **)&LHInterfaceInventoryCFNetworkCopySystemProxySettingsOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "SCDynamicStoreCopyProxies",
                                                (void *)LHInterfaceInventorySCDynamicStoreCopyProxiesReplacement,
                                                (void **)&LHInterfaceInventorySCDynamicStoreCopyProxiesOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "SCDynamicStoreCopyProxiesWithOptions",
                                                (void *)LHInterfaceInventorySCDynamicStoreCopyProxiesWithOptionsReplacement,
                                                (void **)&LHInterfaceInventorySCDynamicStoreCopyProxiesWithOptionsOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "nw_interface_get_name",
                                                (void *)LHInterfaceInventoryNwInterfaceGetNameReplacement,
                                                (void **)&LHInterfaceInventoryNwInterfaceGetNameOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "nw_interface_get_type",
                                                (void *)LHInterfaceInventoryNwInterfaceGetTypeReplacement,
                                                (void **)&LHInterfaceInventoryNwInterfaceGetTypeOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "nw_path_uses_interface_type",
                                                (void *)LHInterfaceInventoryNwPathUsesInterfaceTypeReplacement,
                                                (void **)&LHInterfaceInventoryNwPathUsesInterfaceTypeOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "nw_path_is_expensive",
                                                (void *)LHInterfaceInventoryNwPathIsExpensiveReplacement,
                                                (void **)&LHInterfaceInventoryNwPathIsExpensiveOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "nw_path_is_constrained",
                                                (void *)LHInterfaceInventoryNwPathIsConstrainedReplacement,
                                                (void **)&LHInterfaceInventoryNwPathIsConstrainedOriginalImplementation) || installed;
    installed = LHHookBackendHookImportedSymbol(backend,
                                                "nw_path_enumerate_interfaces",
                                                (void *)LHInterfaceInventoryNwPathEnumerateInterfacesReplacement,
                                                (void **)&LHInterfaceInventoryNwPathEnumerateInterfacesOriginalImplementation) || installed;

    if (!installed) {
        return LHHookBackendRegisterNoOp(backend, LHModuleID_network_interface_inventory_composite_common);
    }
    return true;
}
