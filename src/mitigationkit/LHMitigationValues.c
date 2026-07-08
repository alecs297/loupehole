#include "LHMitigationValues.h"

#include <string.h>

#define LH_UUID_STRING_LENGTH 37

/** Adapts a mitigation policy seed to the derivation-label ABI. */
static void LHMitigationPolicySeedToLabel(const LHPolicySeed *policySeed, LHDerivationLabel *label) {
    memcpy(label->bytes, policySeed->bytes, sizeof(label->bytes));
}

/** Derives mitigation-owned bytes from practical seed, policy seed, scope, and context. */
bool LHMitigationDeriveBytes(const LHSeed *seed,
                             const LHPolicySeed *policySeed,
                             const LHScope *scope,
                             const uint8_t *context,
                             size_t contextLength,
                             uint8_t *output,
                             size_t outputLength) {
    if (seed == 0 || policySeed == 0 || scope == 0 || output == 0 || outputLength == 0) {
        return false;
    }

    LHDerivationLabel label;
    LHMitigationPolicySeedToLabel(policySeed, &label);
    return LHSeedDeriveBytesWithContext(seed, &label, scope, context, contextLength, output, outputLength);
}

/** Derives a little-endian 64-bit value for mitigation use. */
bool LHMitigationDeriveU64(const LHSeed *seed,
                           const LHPolicySeed *policySeed,
                           const LHScope *scope,
                           const uint8_t *context,
                           size_t contextLength,
                           uint64_t *output) {
    if (output == 0) {
        return false;
    }

    uint8_t bytes[8] = { 0 };
    if (!LHMitigationDeriveBytes(seed, policySeed, scope, context, contextLength, bytes, sizeof(bytes))) {
        return false;
    }

    uint64_t value = 0;
    for (size_t index = 0; index < sizeof(value); index++) {
        value |= ((uint64_t)bytes[index]) << (index * 8);
    }
    *output = value;
    return true;
}

/** Derives a bounded 64-bit value with deterministic reduction. */
bool LHMitigationDeriveBoundedU64(const LHSeed *seed,
                                  const LHPolicySeed *policySeed,
                                  const LHScope *scope,
                                  const uint8_t *context,
                                  size_t contextLength,
                                  uint64_t upperBound,
                                  uint64_t *output) {
    if (output == 0 || upperBound == 0) {
        return false;
    }

    uint64_t value = 0;
    if (!LHMitigationDeriveU64(seed, policySeed, scope, context, contextLength, &value)) {
        return false;
    }

    *output = value % upperBound;
    return true;
}

/** Derives a deterministic version 4 UUID string for mitigation use. */
bool LHMitigationDeriveUUIDString(const LHSeed *seed,
                                  const LHPolicySeed *policySeed,
                                  const LHScope *scope,
                                  char *output,
                                  size_t outputLength) {
    if (output == 0 || outputLength < LH_UUID_STRING_LENGTH) {
        return false;
    }

    uint8_t bytes[16] = { 0 };
    if (!LHMitigationDeriveBytes(seed, policySeed, scope, 0, 0, bytes, sizeof(bytes))) {
        return false;
    }
    bytes[6] = (uint8_t)((bytes[6] & 0x0f) | 0x40);
    bytes[8] = (uint8_t)((bytes[8] & 0x3f) | 0x80);

    static const char digits[] = "0123456789abcdef";
    size_t offset = 0;
    for (size_t index = 0; index < sizeof(bytes); index++) {
        if (index == 4 || index == 6 || index == 8 || index == 10) {
            output[offset++] = '-';
        }
        output[offset++] = digits[(bytes[index] >> 4) & 0x0f];
        output[offset++] = digits[bytes[index] & 0x0f];
    }
    output[offset] = '\0';
    return true;
}

/** Derives a deterministic ASCII string from a caller-provided alphabet. */
bool LHMitigationDeriveASCIIString(const LHSeed *seed,
                                   const LHPolicySeed *policySeed,
                                   const LHScope *scope,
                                   const char *alphabet,
                                   size_t length,
                                   char *output,
                                   size_t outputLength) {
    if (alphabet == 0 || alphabet[0] == '\0' || output == 0 || outputLength <= length || length == 0 || length > 64) {
        return false;
    }

    size_t alphabetLength = strlen(alphabet);
    uint8_t bytes[64] = { 0 };
    if (!LHMitigationDeriveBytes(seed, policySeed, scope, 0, 0, bytes, length)) {
        return false;
    }

    for (size_t index = 0; index < length; index++) {
        output[index] = alphabet[bytes[index] % alphabetLength];
    }
    output[length] = '\0';
    return true;
}

/** Derives a double timestamp inside an exclusive upper-bound interval. */
bool LHMitigationDeriveTimeIntervalBetween(const LHSeed *seed,
                                           const LHPolicySeed *policySeed,
                                           const LHScope *scope,
                                           double lowerInclusive,
                                           double upperExclusive,
                                           double *output) {
    if (output == 0 || !(upperExclusive > lowerInclusive)) {
        return false;
    }

    uint64_t value = 0;
    if (!LHMitigationDeriveU64(seed, policySeed, scope, 0, 0, &value)) {
        return false;
    }

    long double unit = (long double)value / ((long double)UINT64_MAX + 1.0L);
    *output = lowerInclusive + ((upperExclusive - lowerInclusive) * (double)unit);
    return *output >= lowerInclusive && *output < upperExclusive;
}

/** Builds a state key from a generated mitigation policy seed. */
LHStateKey LHMitigationStateKeyFromPolicySeed(const LHPolicySeed *policySeed, uint32_t schemaVersion) {
    LHStateKey key;
    memset(&key, 0, sizeof(key));
    if (policySeed != 0) {
        memcpy(key.label.bytes, policySeed->bytes, sizeof(key.label.bytes));
    }
    key.schemaVersion = schemaVersion;
    return key;
}
