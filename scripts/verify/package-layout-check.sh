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
filter="$root/var/jb/Library/MobileSubstrate/DynamicLibraries/runtime.plist"
install_refresh_filter="$root/var/jb/Library/MobileSubstrate/DynamicLibraries/installrefresh.plist"
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

require_file "$root/var/jb/Library/MobileSubstrate/DynamicLibraries/runtime.dylib"
require_file "$filter"
require_file "$root/var/jb/Library/MobileSubstrate/DynamicLibraries/installrefresh.dylib"
require_file "$install_refresh_filter"
require_file "$toggle_helper"
if [ ! -x "$toggle_helper" ]; then
  printf '%s\n' "toggle helper is not executable"
  exit 1
fi

for script in preinst postinst prerm postrm; do
  require_file "$control/$script"
  if [ ! -x "$control/$script" ]; then
    printf '%s\n' "maintainer script is not executable: $script"
    exit 1
  fi
done

state_parent=$(python3 - "$root" "$control" "$filter" <<'PY'
import os
import plistlib
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
control = Path(sys.argv[2])
filter_path = Path(sys.argv[3])
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
postrm_text = (control / "postrm").read_text(encoding="utf-8")
for script_name, script_text in (("postinst", postinst_text), ("postrm", postrm_text)):
    if state_parent not in script_text:
        raise SystemExit(f"{script_name} does not reference generated state parent")

script_values = {}
for line in postinst_text.splitlines():
    match = re.fullmatch(r"(STATE_PARENT|SEED_ROOT_DIR|ROOT_SEED_FILE|POLICY_FILE)=([0-9a-f]{32})", line)
    if match:
        script_values[match.group(1)] = match.group(2)
if script_values.get("STATE_PARENT") != state_parent:
    raise SystemExit("postinst state parent does not match package layout")
seed_root_dir = script_values.get("SEED_ROOT_DIR")
root_seed_file = script_values.get("ROOT_SEED_FILE")
policy_file = script_values.get("POLICY_FILE")
if seed_root_dir is None or root_seed_file is None or policy_file is None:
    raise SystemExit("postinst is missing generated seed root names")
seed_root = root / "var/jb/var/mobile/Library/Application Support" / state_parent / seed_root_dir
if not seed_root.is_dir():
    raise SystemExit("package layout is missing generated seed root directory")
helper_text = (root / "var/jb/usr/bin/lhctl").read_text(encoding="utf-8")
if policy_file not in helper_text:
    raise SystemExit("toggle helper does not reference generated policy file")
if "awk" in helper_text:
    raise SystemExit("toggle helper must not require awk")
old_selector_pattern = r"\bmo" "de\\b|\\bmo" "des\\b|compat" "ibility|stan" "dard|str" "ict"
if re.search(old_selector_pattern, helper_text):
    raise SystemExit("toggle helper must not expose the old profile selector")
if "LHCTL_APP_BUNDLE_ROOTS" not in helper_text or "refresh_filter" not in helper_text or "refresh-auto" not in helper_text:
    raise SystemExit("toggle helper must support materialized third-party default targeting")

with filter_path.open("rb") as handle:
    data = plistlib.load(handle)

bundles = data.get("Filter", {}).get("Bundles")
if bundles != []:
    raise SystemExit("package filter must start with an empty Bundles allowlist")

with (root / "var/jb/Library/MobileSubstrate/DynamicLibraries/installrefresh.plist").open("rb") as handle:
    trigger_data = plistlib.load(handle)
trigger_filter = trigger_data.get("Filter", {})
if trigger_filter.get("Executables") != ["installd"]:
    raise SystemExit("install refresh trigger must target only installd")
if "Bundles" in trigger_filter:
    raise SystemExit("install refresh trigger must not target app bundles")

print(state_parent)
PY
)

require_dir "$root/var/jb/var/mobile/Library/Application Support/$state_parent"
require_dir "$root/var/jb/var/mobile/Library/Caches/$state_parent"
require_dir "$root/var/jb/var/mobile/Library/Preferences/$state_parent"

bundles_from_filter() {
  python3 - "$filter" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as handle:
    data = plistlib.load(handle)
for bundle in data.get("Filter", {}).get("Bundles", []):
    print(bundle)
PY
}

assert_filter_bundles() {
  python3 - "$filter" "$@" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as handle:
    data = plistlib.load(handle)
actual = data.get("Filter", {}).get("Bundles", [])
expected = sys.argv[2:]
if sorted(actual) != sorted(expected):
    raise SystemExit(f"filter bundles mismatch: actual={actual!r} expected={expected!r}")
PY
}

app_root="$tmpdir/apps"
make_test_app() {
  bundle_id=${1:?}
  app_name=${2:?}
  app_dir="$app_root/$app_name.app"
  mkdir -p "$app_dir"
  cat >"$app_dir/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>$bundle_id</string>
</dict>
</plist>
PLIST
}

lhctl() {
  LHCTL_ALLOW_NONROOT=1 ROOT_PREFIX="$root/var/jb" LHCTL_APP_BUNDLE_ROOTS="$app_root" "$toggle_helper" "$@"
}

make_test_app com.example.one One
make_test_app com.example.two Two
make_test_app com.example.three Three
make_test_app com.apple.Maps AppleMaps

lhctl refresh-auto >/dev/null
assert_filter_bundles

lhctl default enabled on >/dev/null
assert_filter_bundles com.example.one com.example.two com.example.three

make_test_app com.example.four Four
lhctl refresh-auto >/dev/null
assert_filter_bundles com.example.one com.example.two com.example.three com.example.four

lhctl disable com.example.two >/dev/null
assert_filter_bundles com.example.one com.example.three com.example.four

lhctl set com.example.one scope per-vendor-group >/dev/null
lhctl set com.example.one mitigations system.boot_time.composite.synthetic storage.volume_creation_time.foundation.synthetic >/dev/null
lhctl default scope per-app >/dev/null
lhctl default mitigations identity.idfv.uidevice.scoped_uuid >/dev/null
assert_filter_bundles com.example.one com.example.three com.example.four

lhctl default enabled off >/dev/null
assert_filter_bundles com.example.one

make_test_app com.example.five Five
lhctl refresh-auto >/dev/null
assert_filter_bundles com.example.one

lhctl toggle com.example.three >/dev/null
lhctl disable com.example.one >/dev/null
assert_filter_bundles com.example.three

python3 - "$root" "$state_parent" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
state_parent = sys.argv[2]
config_dir = root / "var/jb/var/mobile/Library/Preferences" / state_parent
policy_files = [path for path in config_dir.iterdir() if re.fullmatch(r"[0-9a-f]{32}", path.name)]
if len(policy_files) != 1:
    raise SystemExit("expected one generated policy file")

entries = {}
for line in policy_files[0].read_text(encoding="utf-8").splitlines():
    fields = line.split("|")
    if not fields:
        continue
    if fields[0] == "D":
        entries["D"] = fields
    elif fields[0] == "B" and len(fields) > 1:
        entries[fields[1]] = fields

if entries.get("D") != ["D", "0", "1", "1", "1"]:
    raise SystemExit(f"default policy mismatch: {entries.get('D')}")
if entries.get("com.example.one") != ["B", "com.example.one", "0", "2", "1", "2,3"]:
    raise SystemExit(f"bundle one policy mismatch: {entries.get('com.example.one')}")
if entries.get("com.example.two") != ["B", "com.example.two", "0", "0", "0", ""]:
    raise SystemExit(f"bundle two policy mismatch: {entries.get('com.example.two')}")
if entries.get("com.example.three") != ["B", "com.example.three", "1", "1", "1", "1"]:
    raise SystemExit(f"bundle three policy mismatch: {entries.get('com.example.three')}")
PY

lhctl clear >/dev/null
assert_filter_bundles

python3 - "$root" "$state_parent" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
state_parent = sys.argv[2]
config_dir = root / "var/jb/var/mobile/Library/Preferences" / state_parent
policy_file = next(path for path in config_dir.iterdir() if re.fullmatch(r"[0-9a-f]{32}", path.name))
for line in policy_file.read_text(encoding="utf-8").splitlines():
    fields = line.split("|")
    if fields and fields[0] == "D" and len(fields) > 1 and fields[1] != "0":
        raise SystemExit("clear did not disable default policy")
    if fields and fields[0] == "B" and len(fields) > 2 and fields[2] != "0":
        raise SystemExit("clear did not disable bundle policy entries")
PY

printf '%s\n' "package layout check passed"
