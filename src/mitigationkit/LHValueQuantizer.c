#include "LHValueQuantizer.h"

/** Rounds a value down to the nearest bucket boundary. */
uint64_t LHValueQuantizeDown(uint64_t value, uint64_t bucketSize) {
    if (bucketSize == 0) {
        return value;
    }

    return value - (value % bucketSize);
}
