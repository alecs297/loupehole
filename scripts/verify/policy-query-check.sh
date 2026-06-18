#!/bin/sh
set -eu

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/policy_check.m" <<'SOURCE'
#include "LHPolicyEngine.h"
#include "LHGeneratedPolicyValueRegistry.h"

#include <stdio.h>
#include <string.h>

#define LH_TEST_UUID_STRING_LENGTH 37

int main(void) {
    LHPolicyEngine engine;
    if (!LHPolicyEngineInit(&engine)) {
        return 1;
    }

    char idfv[LH_TEST_UUID_STRING_LENGTH] = {0};
    struct timeval bootTime = {0};
    double volumeTime = 0.0;
    LHPolicyValueResponse response;

    LHPolicyValueRequest idfvRequest = {
        .valueID = LHPolicyValueID_identifier_for_vendor,
        .expectedKind = LHPolicyValueKindUTF8String,
        .output = idfv,
        .outputLength = sizeof(idfv)
    };
    if (!LHPolicyEngineCopyValue(&engine, &idfvRequest, &response)) {
        return 2;
    }
    if (response.kind != LHPolicyValueKindUTF8String || response.bytesWritten != sizeof(idfv) || strlen(idfv) != 36) {
        return 3;
    }

    LHPolicyValueRequest bootRequest = {
        .valueID = LHPolicyValueID_boot_time,
        .expectedKind = LHPolicyValueKindTimeval,
        .output = &bootTime,
        .outputLength = sizeof(bootTime)
    };
    if (!LHPolicyEngineCopyValue(&engine, &bootRequest, &response)) {
        return 4;
    }
    if (response.kind != LHPolicyValueKindTimeval || response.bytesWritten != sizeof(bootTime) || bootTime.tv_sec <= 0) {
        return 5;
    }

    LHPolicyValueRequest volumeRequest = {
        .valueID = LHPolicyValueID_volume_creation_time,
        .expectedKind = LHPolicyValueKindTimeInterval,
        .output = &volumeTime,
        .outputLength = sizeof(volumeTime)
    };
    if (!LHPolicyEngineCopyValue(&engine, &volumeRequest, &response)) {
        return 6;
    }
    if (response.kind != LHPolicyValueKindTimeInterval || response.bytesWritten != sizeof(volumeTime) || !(volumeTime < (double)bootTime.tv_sec)) {
        return 7;
    }

    LHPolicyValueRequest wrongKind = {
        .valueID = LHPolicyValueID_boot_time,
        .expectedKind = LHPolicyValueKindUTF8String,
        .output = idfv,
        .outputLength = sizeof(idfv)
    };
    if (LHPolicyEngineCopyValue(&engine, &wrongKind, &response)) {
        return 8;
    }

    LHPolicyValueRequest smallBuffer = {
        .valueID = LHPolicyValueID_identifier_for_vendor,
        .expectedKind = LHPolicyValueKindUTF8String,
        .output = idfv,
        .outputLength = 4
    };
    if (LHPolicyEngineCopyValue(&engine, &smallBuffer, &response)) {
        return 9;
    }

    return 0;
}
SOURCE

cc \
  -DLH_STATE_TESTING=1 \
  -Icore/include \
  -Icore/generated \
  core/generated/LHGeneratedConfig.c \
  core/generated/LHGeneratedDerivationLabels.c \
  core/generated/LHGeneratedPolicyValueRegistry.c \
  core/src/LHAppContext.m \
  core/src/LHConfig.c \
  core/src/LHPolicyEngine.c \
  core/src/LHProfile.c \
  core/src/LHScope.c \
  core/src/LHSeed.c \
  core/src/LHSeedProvider.m \
  core/src/LHStateProvider.m \
  packages/tweak/sources/identity/idfv/IDFVPolicyValue.c \
  packages/tweak/sources/state_domains/temporal_lifetime/TemporalLifetimeState.c \
  "$tmpdir/policy_check.m" \
  -framework Foundation \
  -o "$tmpdir/policy_check"

LH_STATE_TEST_HOME="$tmpdir" "$tmpdir/policy_check"
printf '%s\n' "policy query check passed"
