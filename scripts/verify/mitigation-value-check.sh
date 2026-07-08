#!/bin/sh
set -eu

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/mitigation_value_check.m" <<'SOURCE'
#include "LHPolicyEngine.h"
#include "LHGeneratedPolicySeeds.h"
#include "LHMitigationValues.h"
#include "system/boot_time/BootTimeValues.h"
#include "storage/volume_creation_time/VolumeCreationTimeValues.h"

#include <stdio.h>
#include <string.h>

#define LH_TEST_UUID_STRING_LENGTH 37

int main(void) {
    LHPolicyEngine engine;
    if (!LHPolicyEngineInit(&engine)) {
        return 1;
    }

    char idfv[LH_TEST_UUID_STRING_LENGTH] = {0};
    if (!LHMitigationDeriveUUIDString(&engine.config.buildSeed,
                                 &LHGeneratedPolicySeed_identifier_for_vendor,
                                 &engine.appContext.scope,
                                 idfv,
                                 sizeof(idfv))) {
        return 2;
    }
    if (strlen(idfv) != 36 || idfv[14] != '4') {
        return 3;
    }

    char small[4] = {0};
    if (LHMitigationDeriveUUIDString(&engine.config.buildSeed,
                                &LHGeneratedPolicySeed_identifier_for_vendor,
                                &engine.appContext.scope,
                                small,
                                sizeof(small))) {
        return 4;
    }

    struct timeval bootTime = {0};
    double volumeTime = 0.0;
    if (!LHBootTimeCopySyntheticBootTime(&engine, &bootTime)) {
        return 5;
    }
    if (!LHVolumeCreationTimeCopySyntheticTimestamp(&engine, &volumeTime)) {
        return 6;
    }
    if (bootTime.tv_sec <= 0 || !(volumeTime < (double)bootTime.tv_sec)) {
        return 7;
    }

    uint64_t bounded = 0;
    if (!LHMitigationDeriveBoundedU64(&engine.config.buildSeed,
                                 &LHGeneratedPolicySeed_boot_time,
                                 &engine.appContext.scope,
                                 0,
                                 0,
                                 10,
                                 &bounded) ||
        bounded >= 10) {
        return 8;
    }

    return 0;
}
SOURCE

cc \
  -DLH_STATE_TESTING=1 \
  -Icore/include \
  -Icore/generated \
  -Isrc/mitigations \
  core/generated/LHGeneratedConfig.c \
  core/generated/LHGeneratedDerivationLabels.c \
  core/generated/LHGeneratedPolicySeeds.c \
  src/runtime/context/LHAppContext.m \
  src/runtime/config/LHConfig.c \
  src/runtime/config/LHConfigProvider.m \
  src/runtime/engine/LHPolicyEngine.c \
  src/runtime/scope/LHScope.c \
  src/runtime/seeds/LHSeed.c \
  src/runtime/seeds/LHSeedProvider.m \
  src/runtime/state/LHStateProvider.m \
  src/mitigationkit/LHMitigationValues.c \
  src/mitigations/system/boot_time/BootTimeValues.c \
  src/mitigations/storage/volume_creation_time/VolumeCreationTimeValues.c \
  "$tmpdir/mitigation_value_check.m" \
  -framework Foundation \
  -o "$tmpdir/mitigation_value_check"

LH_STATE_TEST_HOME="$tmpdir" "$tmpdir/mitigation_value_check"

cat >"$tmpdir/package_enablement_check.m" <<'SOURCE'
#include "LHPolicyEngine.h"
#include "LHGeneratedMitigationRegistry.h"

#include <stdio.h>
#include <string.h>

int main(int argc, char **argv) {
    bool expectEnabled = argc > 1 && strcmp(argv[1], "enabled") == 0;

    LHPolicyEngine engine;
    if (!LHPolicyEngineInit(&engine)) {
        return 1;
    }

    bool enabled = LHPolicyEngineIsModuleEnabled(&engine, LHModuleID_identity_idfv_uidevice_scoped_uuid);
    if (expectEnabled) {
        return enabled ? 0 : 2;
    }
    return enabled ? 3 : 0;
}
SOURCE

cc \
  -DLH_STATE_TESTING=1 \
  -DLH_DEFAULT_STATE_PROVIDER_KIND=LHStateProviderKindPackage \
  -DLH_EMBED_BUILD_SEED=0 \
  -Icore/include \
  -Icore/generated \
  core/generated/LHGeneratedConfig.c \
  core/generated/LHGeneratedDerivationLabels.c \
  src/runtime/context/LHAppContext.m \
  src/runtime/config/LHConfig.c \
  src/runtime/config/LHConfigProvider.m \
  src/runtime/engine/LHPolicyEngine.c \
  src/runtime/scope/LHScope.c \
  src/runtime/seeds/LHSeed.c \
  src/runtime/seeds/LHSeedProvider.m \
  src/runtime/state/LHStateProvider.m \
  "$tmpdir/package_enablement_check.m" \
  -framework Foundation \
  -o "$tmpdir/package_enablement_check"

state_parent_and_policy=$(python3 - <<'PY'
import re
from pathlib import Path

text = Path("core/generated/LHGeneratedConfig.c").read_text(encoding="utf-8")
values = dict(re.findall(r'LHGeneratedConfig(PackageStateParentDirectoryName|PackagePolicyFileName)\[\] = "([0-9a-f]{32})"', text))
print(values["PackageStateParentDirectoryName"], values["PackagePolicyFileName"])
PY
)
set -- $state_parent_and_policy
state_parent=$1
policy_file=$2
policy_dir="$tmpdir/package/var/mobile/Library/Preferences/$state_parent"
mkdir -p "$policy_dir"
target_env() {
  LH_PACKAGE_STATE_TEST_ROOT="$tmpdir/package" \
  LH_APP_CONTEXT_TEST_BUNDLE_ID=com.example.host \
  LH_APP_CONTEXT_TEST_BUNDLE_PATH=/var/containers/Bundle/Application/AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE/Host.app \
  LH_APP_CONTEXT_TEST_EXECUTABLE_PATH=/var/containers/Bundle/Application/AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE/Host.app/Host \
    "$tmpdir/package_enablement_check" "$@"
}

printf 'D|0|0|0||\n' > "$policy_dir/$policy_file"
target_env disabled

printf 'D|1|0|0||\n' > "$policy_dir/$policy_file"
target_env enabled

printf 'D|1|3|0||11111111-1111-1111-1111-111111111111\n' > "$policy_dir/$policy_file"
target_env enabled

printf 'D|1|3|0||not-a-uuid\n' > "$policy_dir/$policy_file"
target_env disabled

printf 'D|1|0|0||\nB|com.example.host|0|0|0||\n' > "$policy_dir/$policy_file"
target_env disabled

printf 'D|1|0|0||\n' > "$policy_dir/$policy_file"
LH_PACKAGE_STATE_TEST_ROOT="$tmpdir/package" \
LH_APP_CONTEXT_TEST_BUNDLE_ID=com.apple.Maps \
LH_APP_CONTEXT_TEST_BUNDLE_PATH=/Applications/Maps.app \
LH_APP_CONTEXT_TEST_EXECUTABLE_PATH=/Applications/Maps.app/Maps \
  "$tmpdir/package_enablement_check" disabled

LH_PACKAGE_STATE_TEST_ROOT="$tmpdir/package" \
LH_APP_CONTEXT_TEST_BUNDLE_ID=com.example.extension \
LH_APP_CONTEXT_TEST_BUNDLE_PATH=/var/containers/Bundle/Application/AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE/Host.app/PlugIns/Widget.appex \
LH_APP_CONTEXT_TEST_EXECUTABLE_PATH=/var/containers/Bundle/Application/AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE/Host.app/PlugIns/Widget.appex/Widget \
  "$tmpdir/package_enablement_check" disabled

printf '%s\n' "mitigation value check passed"
