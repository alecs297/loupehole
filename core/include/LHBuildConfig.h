#ifndef LH_BUILD_CONFIG_H
#define LH_BUILD_CONFIG_H

#ifndef LH_ENABLE_VARIABILITY
#define LH_ENABLE_VARIABILITY 0
#endif

#ifndef LH_ENABLE_DIAGNOSTICS
#define LH_ENABLE_DIAGNOSTICS 0
#endif

#define LH_INTERNAL __attribute__((visibility("hidden")))

#endif
