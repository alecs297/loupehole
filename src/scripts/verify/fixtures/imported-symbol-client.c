#include <ifaddrs.h>
#include <sys/sysctl.h>

extern int lh_fixture_value(int value);

static int (*LHFixturePointer)(int) = lh_fixture_value;

int lh_fixture_call(int value) {
    return lh_fixture_value(value);
}

int lh_fixture_pointer_call(int value) {
    return LHFixturePointer(value);
}

int lh_fixture_getifaddrs(void) {
    struct ifaddrs *addresses = 0;
    int result = getifaddrs(&addresses);
    if (result == 0) {
        freeifaddrs(addresses);
    }
    return result;
}

int lh_fixture_sysctl(void) {
    int mib[] = { CTL_KERN, KERN_OSTYPE };
    char value[64];
    size_t size = sizeof(value);
    return sysctl(mib, 2, value, &size, 0, 0);
}
