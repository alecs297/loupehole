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
if re.search(r'\$\(field "\$\((default_line|effective_bundle_line)', helper_text):
    raise SystemExit("toggle helper must avoid nested quoted command substitutions")
old_selector_pattern = r"\bmo" "de\\b|\\bmo" "des\\b|compat" "ibility|stan" "dard|str" "ict"
if re.search(old_selector_pattern, helper_text):
    raise SystemExit("toggle helper must not expose the old profile selector")

with filter_path.open("rb") as handle:
    data = plistlib.load(handle)

bundles = data.get("Filter", {}).get("Bundles")
if bundles != []:
    raise SystemExit("package filter must start with an empty Bundles allowlist")

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

LHCTL_ALLOW_NONROOT=1 ROOT_PREFIX="$root/var/jb" "$toggle_helper" enable com.example.one >/dev/null
LHCTL_ALLOW_NONROOT=1 ROOT_PREFIX="$root/var/jb" "$toggle_helper" default scope per-app >/dev/null
LHCTL_ALLOW_NONROOT=1 ROOT_PREFIX="$root/var/jb" "$toggle_helper" default mitigations identity.idfv.uidevice.scoped_uuid >/dev/null
LHCTL_ALLOW_NONROOT=1 ROOT_PREFIX="$root/var/jb" "$toggle_helper" set com.example.one scope per-vendor-group >/dev/null
LHCTL_ALLOW_NONROOT=1 ROOT_PREFIX="$root/var/jb" "$toggle_helper" set com.example.one mitigations system.boot_time.composite.synthetic storage.volume_creation_time.foundation.synthetic >/dev/null
LHCTL_ALLOW_NONROOT=1 ROOT_PREFIX="$root/var/jb" "$toggle_helper" toggle com.example.two >/dev/null
LHCTL_ALLOW_NONROOT=1 ROOT_PREFIX="$root/var/jb" "$toggle_helper" disable com.example.one >/dev/null
bundles=$(bundles_from_filter)
if [ "$bundles" != "com.example.two" ]; then
  printf '%s\n' "toggle helper did not update filter allowlist"
  exit 1
fi

if LHCTL_ALLOW_NONROOT=1 ROOT_PREFIX="$root/var/jb" "$toggle_helper" enable com.apple.Maps >/dev/null 2>&1; then
  printf '%s\n' "toggle helper allowed a system bundle"
  exit 1
fi

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
if entries.get("com.example.two") != ["B", "com.example.two", "1", "1", "1", "1"]:
    raise SystemExit(f"bundle two policy mismatch: {entries.get('com.example.two')}")
PY

LHCTL_ALLOW_NONROOT=1 ROOT_PREFIX="$root/var/jb" "$toggle_helper" default enabled on >/dev/null
bundles=$(bundles_from_filter)
if [ "$bundles" != "com.apple.UIKit" ]; then
  printf '%s\n' "default-on policy did not switch to the UIKit app filter"
  exit 1
fi

LHCTL_ALLOW_NONROOT=1 ROOT_PREFIX="$root/var/jb" "$toggle_helper" disable com.example.two >/dev/null
bundles=$(bundles_from_filter)
if [ "$bundles" != "com.apple.UIKit" ]; then
  printf '%s\n' "disabled override should not remove the broad UIKit filter"
  exit 1
fi

status=$(LHCTL_ALLOW_NONROOT=1 ROOT_PREFIX="$root/var/jb" "$toggle_helper" status com.example.two)
case "$status" in
  *"effective: disabled"*) ;;
  *)
    printf '%s\n' "status did not report disabled override"
    exit 1
    ;;
esac

LHCTL_ALLOW_NONROOT=1 ROOT_PREFIX="$root/var/jb" "$toggle_helper" clear >/dev/null
bundles=$(bundles_from_filter)
if [ -n "$bundles" ]; then
  printf '%s\n' "toggle helper did not clear filter allowlist"
  exit 1
fi

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
