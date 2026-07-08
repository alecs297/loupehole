#!/bin/sh
set -eu

artifact=${1:?package path required}

if [ ! -f "$artifact" ]; then
  printf '%s\n' "missing package"
  exit 1
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

root="$tmpdir/root"
control="$tmpdir/control"
dynamic_dir="$root/var/jb/Library/MobileSubstrate/DynamicLibraries"
preference_bundle="$root/var/jb/Library/PreferenceBundles/LoupeholePreferences.bundle"
preference_loader="$root/var/jb/Library/PreferenceLoader/Preferences/Loupehole.plist"
toggle_helper="$root/var/jb/usr/bin/lhctl"

dpkg-deb -x "$artifact" "$root"
dpkg-deb -e "$artifact" "$control"

require_file() {
  if [ ! -f "$1" ]; then
    printf '%s\n' "missing package file: $1"
    exit 1
  fi
}

require_dir() {
  if [ ! -d "$1" ]; then
    printf '%s\n' "missing package directory: $1"
    exit 1
  fi
}

require_dir "$dynamic_dir"
loader_basename=$(python3 - "$dynamic_dir" <<'PY'
import re
import sys
from pathlib import Path

dynamic_dir = Path(sys.argv[1])
dylibs = {path.stem for path in dynamic_dir.glob("*.dylib")}
plists = {path.stem for path in dynamic_dir.glob("*.plist")}
if "runtime" in dylibs or "runtime" in plists:
    raise SystemExit("legacy runtime loader basename must not be packaged")
if dylibs != plists or len(dylibs) != 1:
    raise SystemExit("expected one matching generated loader dylib/plist pair")
loader = next(iter(dylibs))
if not re.fullmatch(r"x[0-9a-f]{31}", loader):
    raise SystemExit("loader basename is not generated/opaque")
print(loader)
PY
)
loader_dylib="$dynamic_dir/$loader_basename.dylib"
filter="$dynamic_dir/$loader_basename.plist"

require_file "$loader_dylib"
require_file "$filter"
require_dir "$preference_bundle"
require_file "$preference_bundle/Info.plist"
require_file "$preference_loader"

if [ -e "$toggle_helper" ]; then
  printf '%s\n' "legacy lhctl helper must not be packaged"
  exit 1
fi

for script in preinst postinst prerm postrm; do
  require_file "$control/$script"
  if [ ! -x "$control/$script" ]; then
    printf '%s\n' "maintainer script is not executable: $script"
    exit 1
  fi
done

state_parent=$(python3 - "$root" "$control" "$filter" "$preference_loader" "$loader_basename" <<'PY'
import plistlib
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
control = Path(sys.argv[2])
filter_path = Path(sys.argv[3])
preference_loader = Path(sys.argv[4])
loader_basename = sys.argv[5]
hex_name = re.compile(r"^[0-9a-f]{32}$")

parents = []
for relative in (
    "var/jb/var/mobile/Library/Application Support",
    "var/jb/var/mobile/Library/Caches",
    "var/jb/var/mobile/Library/Preferences",
):
    directory = root / relative
    if not directory.is_dir():
        raise SystemExit(f"missing package directory: {directory}")
    names = sorted(path.name for path in directory.iterdir() if path.is_dir() and hex_name.fullmatch(path.name))
    if len(names) != 1:
        raise SystemExit(f"expected one generated state parent under {directory}")
    parents.append(names[0])

if len(set(parents)) != 1:
    raise SystemExit("package state parent directory differs across state roots")

state_parent = parents[0]
postinst_text = (control / "postinst").read_text(encoding="utf-8")
prerm_text = (control / "prerm").read_text(encoding="utf-8")
postrm_text = (control / "postrm").read_text(encoding="utf-8")
for script_name, script_text in (("postinst", postinst_text), ("postrm", postrm_text)):
    if state_parent not in script_text:
        raise SystemExit(f"{script_name} does not reference generated state parent")
for script_name, script_text in (("postinst", postinst_text), ("prerm", prerm_text), ("postrm", postrm_text)):
    if loader_basename not in script_text:
        raise SystemExit(f"{script_name} does not reference generated loader basename")
    if "runtime.plist" in script_text or "runtime.dylib" in script_text:
        raise SystemExit(f"{script_name} still references the legacy runtime loader basename")

script_values = {}
for line in postinst_text.splitlines():
    match = re.fullmatch(r"(STATE_PARENT|SEED_ROOT_DIR|ROOT_SEED_FILE|POLICY_FILE)=([0-9a-f]{32})", line)
    if match:
        script_values[match.group(1)] = match.group(2)
    match = re.fullmatch(r"LOADER_BASENAME=(x[0-9a-f]{31})", line)
    if match:
        script_values["LOADER_BASENAME"] = match.group(1)
if script_values.get("STATE_PARENT") != state_parent:
    raise SystemExit("postinst state parent does not match package layout")
if script_values.get("LOADER_BASENAME") != loader_basename:
    raise SystemExit("postinst loader basename does not match package layout")
seed_root_dir = script_values.get("SEED_ROOT_DIR")
root_seed_file = script_values.get("ROOT_SEED_FILE")
policy_file = script_values.get("POLICY_FILE")
if seed_root_dir is None or root_seed_file is None or policy_file is None:
    raise SystemExit("postinst is missing generated seed root names")
seed_root = root / "var/jb/var/mobile/Library/Application Support" / state_parent / seed_root_dir
if not seed_root.is_dir():
    raise SystemExit("package layout is missing generated seed root directory")

if "lhctl" in postinst_text or "lhctl" in postrm_text:
    raise SystemExit("maintainer scripts still reference lhctl")
if "chmod 600 \"$policy_file\"" not in postinst_text:
    raise SystemExit("postinst must keep the policy file non-world-readable")
if "filter_file" not in postinst_text:
    raise SystemExit("postinst must prepare the filter plist for Settings writes")

with filter_path.open("rb") as handle:
    data = plistlib.load(handle)
bundles = data.get("Filter", {}).get("Bundles")
if bundles != []:
    raise SystemExit("package filter must start with an empty Bundles allowlist")

with preference_loader.open("rb") as handle:
    loader = plistlib.load(handle)
entry = loader.get("entry", {})
if entry.get("bundle") != "LoupeholePreferences" or entry.get("detail") != "LHRootListController":
    raise SystemExit("preference loader entry does not point at the Loupehole root controller")

print(state_parent)
PY
)

require_dir "$root/var/jb/var/mobile/Library/Application Support/$state_parent"
require_dir "$root/var/jb/var/mobile/Library/Caches/$state_parent"
require_dir "$root/var/jb/var/mobile/Library/Preferences/$state_parent"

cat >"$tmpdir/preference_store_check.m" <<'SOURCE'
#import "LHPreferenceStore.h"

#import <Foundation/Foundation.h>

#include <sys/stat.h>

static NSArray *bundlesAtPath(NSString *path) {
    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:path];
    return plist[@"Filter"][@"Bundles"] ?: @[];
}

static NSArray *policyLinesAtPath(NSString *path) {
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *line in [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        if ([line length] > 0) {
            [lines addObject:line];
        }
    }
    return lines;
}

/** Returns whether a string has lowercase UUID seed formatting. */
static BOOL uuidShaped(NSString *value) {
    if ([value length] != 36) {
        return NO;
    }
    NSMutableIndexSet *expectedHyphens = [NSMutableIndexSet indexSetWithIndex:8];
    [expectedHyphens addIndex:13];
    [expectedHyphens addIndex:18];
    [expectedHyphens addIndex:23];
    for (NSUInteger index = 0; index < [value length]; index++) {
        unichar character = [value characterAtIndex:index];
        BOOL shouldBeHyphen = [expectedHyphens containsIndex:index];
        if (shouldBeHyphen && character != '-') {
            return NO;
        }
        if (!shouldBeHyphen && ![[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] characterIsMember:character]) {
            return NO;
        }
    }
    return YES;
}

int main(void) {
    @autoreleasepool {
        LHPreferenceStore *store = [[LHPreferenceStore alloc] initWithRootPrefix:nil];
        NSError *error = nil;
        if (![store ensurePolicyWithError:&error]) {
            return 1;
        }
        if ([[[store filterPath] lastPathComponent] isEqualToString:@"runtime.plist"]) {
            return 15;
        }
        if (![[[store filterPath] lastPathComponent] hasSuffix:@".plist"]) {
            return 16;
        }
        if ([[[store loaderDylibPath] lastPathComponent] isEqualToString:@"runtime.dylib"]) {
            return 17;
        }
        if (![[[store loaderDylibPath] lastPathComponent] hasSuffix:@".dylib"]) {
            return 18;
        }

        LHPreferencePolicy *defaultPolicy = [LHPreferencePolicy defaultPolicy];
        defaultPolicy.enabled = YES;
        defaultPolicy.scopeMode = 1;
        defaultPolicy.moduleFilterEnabled = YES;
        defaultPolicy.moduleIDs = @[@1];
        if (![store setDefaultPolicy:defaultPolicy error:&error]) {
            return 2;
        }
        if (![bundlesAtPath([store filterPath]) isEqualToArray:@[@"com.apple.UIKit"]]) {
            return 3;
        }

        LHPreferencePolicy *bundlePolicy = [defaultPolicy copy];
        bundlePolicy.enabled = YES;
        bundlePolicy.scopeMode = 2;
        bundlePolicy.moduleFilterEnabled = YES;
        bundlePolicy.moduleIDs = @[@2, @3];
        if (![store setOverridePolicy:bundlePolicy forBundleIdentifier:@"com.example.one" error:&error]) {
            return 4;
        }
        if (![[store overridePolicyForBundleIdentifier:@"com.example.one"].moduleIDs isEqualToArray:@[@2, @3]]) {
            return 5;
        }

        NSString *firstSeed = @"11111111-1111-1111-1111-111111111111";
        NSString *secondSeed = @"22222222-2222-2222-2222-222222222222";
        bundlePolicy.scopeMode = 3;
        bundlePolicy.customSeed = firstSeed;
        if (![store setOverridePolicy:bundlePolicy forBundleIdentifier:@"com.example.one" error:&error]) {
            return 24;
        }
        if (![store replaceCustomSeed:firstSeed withSeed:secondSeed includingBundleIdentifier:@"com.example.two" error:&error]) {
            return 25;
        }
        if (![[store overridePolicyForBundleIdentifier:@"com.example.one"].customSeed isEqualToString:secondSeed]) {
            return 26;
        }
        LHPreferencePolicy *linkedPolicy = [store overridePolicyForBundleIdentifier:@"com.example.two"];
        if (linkedPolicy.scopeMode != 3 || ![linkedPolicy.customSeed isEqualToString:secondSeed]) {
            return 27;
        }
        if (![store removeOverrideForBundleIdentifier:@"com.example.two" error:&error]) {
            return 28;
        }

        defaultPolicy.enabled = NO;
        defaultPolicy.moduleFilterEnabled = NO;
        defaultPolicy.moduleIDs = @[];
        if (![store setDefaultPolicy:defaultPolicy error:&error]) {
            return 9;
        }
        if (![bundlesAtPath([store filterPath]) isEqualToArray:@[@"com.example.one"]]) {
            return 10;
        }

        if (![store removeOverrideForBundleIdentifier:@"com.example.one" error:&error]) {
            return 11;
        }
        if ([bundlesAtPath([store filterPath]) count] != 0) {
            return 12;
        }

        if (![store resetAllWithError:&error]) {
            return 13;
        }
        NSArray *lines = policyLinesAtPath([store policyPath]);
        if (![lines isEqualToArray:@[@"D|0|0|0||"]]) {
            return 14;
        }
        if ([[store buildSeedString] isEqualToString:@"runtime-random"]) {
            return 29;
        }
        if (![store resetRootSeedWithError:&error]) {
            return 19;
        }
        NSData *firstRootSeed = [NSData dataWithContentsOfFile:[store rootSeedPath]];
        if ([firstRootSeed length] != 16) {
            return 20;
        }
        if (!uuidShaped([store rootSeedUUIDString])) {
            return 30;
        }
        struct stat st;
        if (stat([[store rootSeedPath] fileSystemRepresentation], &st) != 0 || (st.st_mode & 0777) != 0600) {
            return 21;
        }
        if (![store resetRootSeedWithError:&error]) {
            return 22;
        }
        NSData *secondRootSeed = [NSData dataWithContentsOfFile:[store rootSeedPath]];
        if ([secondRootSeed length] != 16 || [firstRootSeed isEqualToData:secondRootSeed]) {
            return 23;
        }
    }
    return 0;
}
SOURCE

cc \
  -DLH_PREFERENCES_TESTING=1 \
  -DLH_EMBED_BUILD_SEED=1 \
  -Icore/include \
  -Icore/generated \
  -Ipackaging/theos/generated \
  -Iui/preferences \
  ui/preferences/LHPreferenceStore.m \
  packaging/theos/generated/LHGeneratedPreferenceMetadata.c \
  core/generated/LHGeneratedConfig.c \
  "$tmpdir/preference_store_check.m" \
  -framework Foundation \
  -o "$tmpdir/preference_store_check"

LH_PREFERENCES_TEST_ROOT="$root/var/jb" "$tmpdir/preference_store_check"

printf '%s\n' "package layout check passed"
