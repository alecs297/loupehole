#include "LHSeed.h"

#include <CommonCrypto/CommonHMAC.h>
#include <string.h>

static int LHHexNibble(char c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    }
    if (c >= 'a' && c <= 'f') {
        return c - 'a' + 10;
    }
    if (c >= 'A' && c <= 'F') {
        return c - 'A' + 10;
    }
    return -1;
}

bool LHSeedParseUUID(const char *uuid, LHSeed *seed) {
    if (uuid == 0 || seed == 0) {
        return false;
    }

    static const uint8_t hyphenPositions[] = { 8, 13, 18, 23 };
    for (size_t i = 0; i < sizeof(hyphenPositions); i++) {
        if (uuid[hyphenPositions[i]] != '-') {
            return false;
        }
    }

    if (uuid[36] != '\0') {
        return false;
    }

    uint8_t output[16] = { 0 };
    size_t byteIndex = 0;
    for (size_t i = 0; i < 36; i++) {
        if (uuid[i] == '-') {
            continue;
        }
        int high = LHHexNibble(uuid[i]);
        int low = LHHexNibble(uuid[++i]);
        if (high < 0 || low < 0 || byteIndex >= sizeof(output)) {
            return false;
        }
        output[byteIndex++] = (uint8_t)((high << 4) | low);
    }

    if (byteIndex != sizeof(output)) {
        return false;
    }

    memcpy(seed->bytes, output, sizeof(seed->bytes));
    return true;
}

static void LHHmacSha256(const uint8_t *key, size_t keyLength, const uint8_t *data, size_t dataLength, uint8_t output[CC_SHA256_DIGEST_LENGTH]) {
    CCHmac(kCCHmacAlgSHA256, key, keyLength, data, dataLength, output);
}

static void LHSeedInfo(const LHScope *scope, const LHDerivationLabel *label, uint8_t *info, size_t *infoLength) {
    size_t offset = 0;
    info[offset++] = 1;
    memcpy(info + offset, label->bytes, sizeof(label->bytes));
    offset += sizeof(label->bytes);
    info[offset++] = (uint8_t)scope->mode;
    if (scope->identifierLength > 0) {
        memcpy(info + offset, scope->identifier, scope->identifierLength);
        offset += scope->identifierLength;
    }
    *infoLength = offset;
}

bool LHSeedDeriveBytes(const LHSeed *seed, const LHDerivationLabel *label, const LHScope *scope, uint8_t *output, size_t outputLength) {
    if (seed == 0 || label == 0 || scope == 0 || output == 0 || outputLength == 0 || outputLength > 64) {
        return false;
    }

    uint8_t extractSalt[CC_SHA256_DIGEST_LENGTH] = { 0 };
    uint8_t prk[CC_SHA256_DIGEST_LENGTH] = { 0 };
    LHHmacSha256(extractSalt, sizeof(extractSalt), seed->bytes, sizeof(seed->bytes), prk);

    uint8_t info[sizeof(scope->identifier) + sizeof(label->bytes) + 2] = { 0 };
    size_t infoLength = 0;
    LHSeedInfo(scope, label, info, &infoLength);

    uint8_t previous[CC_SHA256_DIGEST_LENGTH] = { 0 };
    uint8_t blockInput[sizeof(previous) + sizeof(info) + 1] = { 0 };
    size_t produced = 0;
    uint8_t counter = 1;

    while (produced < outputLength) {
        size_t offset = 0;
        if (counter > 1) {
            memcpy(blockInput, previous, sizeof(previous));
            offset += sizeof(previous);
        }
        memcpy(blockInput + offset, info, infoLength);
        offset += infoLength;
        blockInput[offset++] = counter;

        LHHmacSha256(prk, sizeof(prk), blockInput, offset, previous);
        size_t remaining = outputLength - produced;
        size_t copyLength = remaining < sizeof(previous) ? remaining : sizeof(previous);
        memcpy(output + produced, previous, copyLength);
        produced += copyLength;
        counter++;
    }

    return true;
}

bool LHSeedDeriveOpaqueName(const LHSeed *seed, const LHDerivationLabel *label, const LHScope *scope, char *output, size_t outputLength) {
    if (output == 0 || outputLength < 33) {
        return false;
    }

    uint8_t bytes[16] = { 0 };
    if (!LHSeedDeriveBytes(seed, label, scope, bytes, sizeof(bytes))) {
        return false;
    }

    static const char digits[] = "0123456789abcdef";
    for (size_t i = 0; i < sizeof(bytes); i++) {
        output[i * 2] = digits[(bytes[i] >> 4) & 0x0f];
        output[i * 2 + 1] = digits[bytes[i] & 0x0f];
    }
    output[32] = '\0';
    return true;
}
