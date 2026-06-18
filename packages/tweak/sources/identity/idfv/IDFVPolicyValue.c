#include "LHPolicyEngine.h"
#include "LHGeneratedDerivationLabels.h"

#include <string.h>

#define LH_IDFV_UUID_STRING_LENGTH 37

static void LHIDFVBytesToUUIDString(const uint8_t bytes[16], char output[LH_IDFV_UUID_STRING_LENGTH]) {
    static const char digits[] = "0123456789abcdef";
    size_t offset = 0;
    for (size_t i = 0; i < 16; i++) {
        if (i == 4 || i == 6 || i == 8 || i == 10) {
            output[offset++] = '-';
        }
        output[offset++] = digits[(bytes[i] >> 4) & 0x0f];
        output[offset++] = digits[bytes[i] & 0x0f];
    }
    output[offset] = '\0';
}

static LHStateKey LHIDFVStateKey(void) {
    LHStateKey key = {
        .schemaVersion = 1
    };
    key.label = LHGeneratedDerivationLabel_identifier_for_vendor_state;
    return key;
}

static bool LHIDFVGenerate(const LHRuntimeConfig *config,
                           const LHAppContext *context,
                           void *generatorContext,
                           uint8_t *output,
                           size_t outputLength) {
    (void)generatorContext;
    if (outputLength != LH_IDFV_UUID_STRING_LENGTH) {
        return false;
    }

    uint8_t uuidBytes[16] = { 0 };
    if (!LHSeedDeriveBytes(&config->instanceSeed, &LHGeneratedDerivationLabel_identifier_for_vendor_value, &context->scope, uuidBytes, sizeof(uuidBytes))) {
        return false;
    }

    LHIDFVBytesToUUIDString(uuidBytes, (char *)output);
    return true;
}

bool LHPolicyResolve_identifier_for_vendor(const LHPolicyEngine *engine,
                                           const LHPolicyValueRequest *request,
                                           LHPolicyValueResponse *response) {
    if (request == 0 || request->output == 0 || request->expectedKind != LHPolicyValueKindUTF8String) {
        return false;
    }
    if (request->outputLength < LH_IDFV_UUID_STRING_LENGTH) {
        return false;
    }

    char uuid[LH_IDFV_UUID_STRING_LENGTH] = { 0 };
    LHStateKey key = LHIDFVStateKey();
    if (!LHPolicyEngineLoadOrCreateState(engine,
                                         &key,
                                         (uint8_t *)uuid,
                                         sizeof(uuid),
                                         LHIDFVGenerate,
                                         0,
                                         0)) {
        return false;
    }

    memcpy(request->output, uuid, sizeof(uuid));
    if (response != 0) {
        response->kind = LHPolicyValueKindUTF8String;
        response->bytesWritten = sizeof(uuid);
    }
    return true;
}
