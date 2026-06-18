#ifndef LH_POLICY_VALUE_H
#define LH_POLICY_VALUE_H

#include "LHBuildConfig.h"
#include "LHTypes.h"

#include <sys/time.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LHPolicyEngine LHPolicyEngine;
typedef uint32_t LHPolicyValueID;

typedef enum LHPolicyValueKind {
    LHPolicyValueKindUTF8String = 1,
    LHPolicyValueKindTimeval = 2,
    LHPolicyValueKindTimeInterval = 3
} LHPolicyValueKind;

typedef struct LHPolicyValueRequest {
    LHPolicyValueID valueID;
    LHPolicyValueKind expectedKind;
    void *output;
    size_t outputLength;
} LHPolicyValueRequest;

typedef struct LHPolicyValueResponse {
    LHPolicyValueKind kind;
    size_t bytesWritten;
} LHPolicyValueResponse;

typedef bool (*LHPolicyValueResolver)(const LHPolicyEngine *engine,
                                      const LHPolicyValueRequest *request,
                                      LHPolicyValueResponse *response);

typedef struct LHPolicyValueDescriptor {
    LHPolicyValueID valueID;
    LHPolicyValueKind kind;
    LHPolicyValueResolver resolver;
} LHPolicyValueDescriptor;

#ifdef __cplusplus
}
#endif

#endif
