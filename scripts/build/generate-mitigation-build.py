#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ID_RE = re.compile(r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*){3,}$")
VALUE_ID_RE = re.compile(r"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$")
UUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
LANGUAGES = {"c", "objc", "objcxx"}
STATUSES = {"planned", "experimental", "beta", "stable", "deprecated"}
VALUE_KINDS = {
    "utf8_string": "LHPolicyValueKindUTF8String",
    "timeval": "LHPolicyValueKindTimeval",
    "time_interval": "LHPolicyValueKindTimeInterval",
}
LABEL_NAMESPACE = b"lh.derivation-label.v1\0"
PACKAGE_STATE_PARENT_NAMESPACE = b"lh.package-state-parent.v1\0"
PACKAGE_SEED_ROOT_DIRECTORY_NAMESPACE = b"lh.package-seed-root-directory.v1\0"
PACKAGE_ROOT_SEED_FILE_NAMESPACE = b"lh.package-root-seed-file.v1\0"
LABEL_COMPONENT_RE = re.compile(r"^[a-z][a-z0-9_]*$")
LABEL_DECL_RE = re.compile(r"\bLH_DERIVATION_LABEL\s*\(\s*([a-z][a-z0-9_]*)\s*,\s*([a-z][a-z0-9_]*)\s*\)")


def load_json(path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def as_list(value, name):
    if value is None:
        return []
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise SystemExit(f"{name} must be a list of strings")
    return value


def symbol_for(identifier):
    return "LHMitigation_" + identifier.replace(".", "_") + "_install"


def enum_for(identifier):
    return "LHModuleID_" + identifier.replace(".", "_")


def value_enum_for(identifier):
    return "LHPolicyValueID_" + identifier.replace(".", "_")


def label_symbol_for(identifier):
    return "LHGeneratedDerivationLabel_" + identifier.replace(".", "_")


def parse_uuid_bytes(value, name):
    if value is None:
        return None
    if not isinstance(value, str) or not UUID_RE.match(value):
        raise SystemExit(f"{name} must be a UUID string")
    return bytes.fromhex(value.replace("-", ""))


def label_bytes_for(identifier, instance_seed):
    seed = instance_seed if instance_seed is not None else b""
    digest = hashlib.sha256(LABEL_NAMESPACE + seed + b"\0" + identifier.encode("utf-8")).digest()
    return digest[:16]


def byte_initializer(data):
    return "{ " + ", ".join(f"0x{byte:02x}" for byte in data) + " }"


def generated_hex_name(namespace, instance_seed):
    seed = instance_seed if instance_seed is not None else b""
    return hashlib.sha256(namespace + seed).hexdigest()[:32]


def package_state_parent_name(instance_seed):
    return generated_hex_name(PACKAGE_STATE_PARENT_NAMESPACE, instance_seed)


def package_seed_root_directory_name(instance_seed):
    return generated_hex_name(PACKAGE_SEED_ROOT_DIRECTORY_NAMESPACE, instance_seed)


def package_root_seed_file_name(instance_seed):
    return generated_hex_name(PACKAGE_ROOT_SEED_FILE_NAMESPACE, instance_seed)


def normalize_catalog(catalog):
    defaults = catalog.get("defaults", {})
    raw = catalog.get("mitigations", [])
    if not isinstance(raw, list):
        raise SystemExit("catalog mitigations must be a list")

    mitigations = {}
    for item in raw:
        if not isinstance(item, dict):
            raise SystemExit("each mitigation must be an object")

        identifier = item.get("id")
        if not isinstance(identifier, str) or not ID_RE.match(identifier):
            raise SystemExit(f"invalid mitigation id: {identifier}")
        if identifier in mitigations:
            raise SystemExit(f"duplicate mitigation id: {identifier}")

        sources = as_list(item.get("sources"), f"{identifier}.sources")
        if not sources:
            raise SystemExit(f"{identifier} must list at least one source")
        for source in sources:
            if not (ROOT / source).is_file():
                raise SystemExit(f"{identifier} source does not exist: {source}")

        language = item.get("language")
        if language not in LANGUAGES:
            raise SystemExit(f"{identifier} language must be one of {sorted(LANGUAGES)}")

        status = item.get("status")
        if status not in STATUSES:
            raise SystemExit(f"{identifier} status must be one of {sorted(STATUSES)}")

        normalized = dict(item)
        for key in ("requires", "conflicts", "frameworks", "weakFrameworks", "libraries"):
            normalized[key] = as_list(item.get(key, defaults.get(key, [])), f"{identifier}.{key}")
        normalized["policyValues"] = as_list(item.get("policyValues"), f"{identifier}.policyValues")
        normalized["minIos"] = item.get("minIos", defaults.get("minIos", "15.0"))
        normalized["maxIos"] = item.get("maxIos", defaults.get("maxIos"))
        normalized["symbol"] = symbol_for(identifier)
        normalized["enum"] = enum_for(identifier)
        mitigations[identifier] = normalized

    for identifier, item in mitigations.items():
        for key in ("requires", "conflicts"):
            for dependency in item[key]:
                if dependency not in mitigations:
                    raise SystemExit(f"{identifier} references unknown {key} mitigation: {dependency}")

    return mitigations


def source_for_label_scan(text):
    output = []
    state = "code"
    i = 0
    while i < len(text):
        char = text[i]
        next_char = text[i + 1] if i + 1 < len(text) else ""

        if state == "code":
            if char == "/" and next_char == "/":
                output.extend("  ")
                i += 2
                state = "line_comment"
                continue
            if char == "/" and next_char == "*":
                output.extend("  ")
                i += 2
                state = "block_comment"
                continue
            if char == '"':
                output.append(" ")
                i += 1
                state = "string"
                continue
            if char == "'":
                output.append(" ")
                i += 1
                state = "char"
                continue
            output.append(char)
            i += 1
            continue

        if state == "line_comment":
            if char == "\n":
                output.append("\n")
                state = "code"
            else:
                output.append(" ")
            i += 1
            continue

        if state == "block_comment":
            if char == "*" and next_char == "/":
                output.extend("  ")
                i += 2
                state = "code"
                continue
            output.append("\n" if char == "\n" else " ")
            i += 1
            continue

        if state in ("string", "char"):
            if char == "\\" and next_char:
                output.extend("  ")
                i += 2
                continue
            if (state == "string" and char == '"') or (state == "char" and char == "'"):
                output.append(" ")
                i += 1
                state = "code"
                continue
            output.append("\n" if char == "\n" else " ")
            i += 1

    return "".join(output)


def discover_derivation_labels(source_paths, instance_seed):
    labels = []
    seen = {}
    for source in source_paths:
        path = ROOT / source
        text = path.read_text(encoding="utf-8")
        scan_text = source_for_label_scan(text)
        for match in LABEL_DECL_RE.finditer(scan_text):
            domain, name = match.groups()
            if not LABEL_COMPONENT_RE.match(domain) or not LABEL_COMPONENT_RE.match(name):
                line = scan_text.count("\n", 0, match.start()) + 1
                raise SystemExit(f"invalid derivation label declaration in {source}:{line}")
            identifier = f"{domain}.{name}"
            line = scan_text.count("\n", 0, match.start()) + 1
            if identifier in seen:
                first_source, first_line = seen[identifier]
                raise SystemExit(
                    f"duplicate derivation label id {identifier}: "
                    f"{source}:{line} also declared in {first_source}:{first_line}"
                )
            seen[identifier] = (source, line)
            labels.append({
                "id": identifier,
                "symbol": label_symbol_for(identifier),
                "bytes": label_bytes_for(identifier, instance_seed),
            })

    return labels


def normalize_policy_values(catalog):
    defaults = catalog.get("defaults", {})
    raw = catalog.get("values", [])
    if not isinstance(raw, list):
        raise SystemExit("policy values must be a list")

    values = {}
    for item in raw:
        if not isinstance(item, dict):
            raise SystemExit("each policy value must be an object")

        identifier = item.get("id")
        if not isinstance(identifier, str) or not VALUE_ID_RE.match(identifier):
            raise SystemExit(f"invalid policy value id: {identifier}")
        if identifier in values:
            raise SystemExit(f"duplicate policy value id: {identifier}")

        kind = item.get("kind")
        if kind not in VALUE_KINDS:
            raise SystemExit(f"{identifier} kind must be one of {sorted(VALUE_KINDS)}")

        resolver = item.get("resolver")
        if not isinstance(resolver, str) or not re.match(r"^LHPolicyResolve_[A-Za-z0-9_]+$", resolver):
            raise SystemExit(f"{identifier} resolver is invalid")

        sources = as_list(item.get("sources", defaults.get("sources", [])), f"{identifier}.sources")
        if not sources:
            raise SystemExit(f"{identifier} must list at least one resolver source")
        for source in sources:
            if not (ROOT / source).is_file():
                raise SystemExit(f"{identifier} resolver source does not exist: {source}")

        normalized = dict(item)
        normalized["sources"] = sources
        normalized["kindSymbol"] = VALUE_KINDS[kind]
        normalized["enum"] = value_enum_for(identifier)
        values[identifier] = normalized

    return values


def validate_selection(selection, mitigations, policy_values):
    selected = selection.get("mitigations")
    if not isinstance(selected, list) or not all(isinstance(item, str) for item in selected):
        raise SystemExit("selection mitigations must be a list of strings")
    if len(selected) != len(set(selected)):
        raise SystemExit("selection contains duplicate mitigations")

    selected_set = set(selected)
    for identifier in selected:
        if identifier not in mitigations:
            raise SystemExit(f"selected mitigation is not in catalog: {identifier}")
        item = mitigations[identifier]
        for value_id in item["policyValues"]:
            if value_id not in policy_values:
                raise SystemExit(f"{identifier} references unknown policy value: {value_id}")
        for required in item["requires"]:
            if required not in selected_set:
                raise SystemExit(f"{identifier} requires {required}")
        for conflict in item["conflicts"]:
            if conflict in selected_set:
                raise SystemExit(f"{identifier} conflicts with {conflict}")

    selected_mitigations = [mitigations[identifier] for identifier in selected]
    selected_value_ids = []
    for item in selected_mitigations:
        selected_value_ids.extend(item["policyValues"])
    selected_values = [policy_values[identifier] for identifier in dict.fromkeys(selected_value_ids)]

    return selected_mitigations, selected_values


def make_words(items):
    return " ".join(dict.fromkeys(items))


def selected_source_paths(selected, selected_values):
    sources = []
    for item in selected:
        sources.extend(item["sources"])
    for item in selected_values:
        sources.extend(item["sources"])
    return list(dict.fromkeys(sources))


def core_derivation_label_source_paths():
    sources = []
    for pattern in ("core/src/*.c", "core/src/*.m", "core/src/*.mm"):
        sources.extend(str(path.relative_to(ROOT)) for path in sorted(ROOT.glob(pattern)))
    return sources


def write_file(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def write_executable(path, text):
    write_file(path, text)
    path.chmod(0o755)


def emit_make_fragment(selected, selected_values):
    sources = []
    policy_value_sources = []
    frameworks = []
    weak_frameworks = []
    libraries = []
    for item in selected:
        sources.extend(os.path.relpath(ROOT / source, ROOT / "packages/tweak") for source in item["sources"])
        frameworks.extend(item["frameworks"])
        weak_frameworks.extend(item["weakFrameworks"])
        libraries.extend(item["libraries"])
    for item in selected_values:
        policy_value_sources.extend(os.path.relpath(ROOT / source, ROOT / "packages/tweak") for source in item["sources"])

    lines = [
        "# Generated by scripts/build/generate-mitigation-build.py.",
        "LH_SELECTED_MITIGATION_SOURCES := " + make_words(sources),
        "LH_SELECTED_POLICY_VALUE_SOURCES := " + make_words(policy_value_sources),
        "LH_SELECTED_FRAMEWORKS := " + make_words(frameworks),
        "LH_SELECTED_WEAK_FRAMEWORKS := " + make_words(weak_frameworks),
        "LH_SELECTED_LIBRARIES := " + make_words(libraries),
        "",
    ]
    write_file(ROOT / "packages/tweak/generated/mitigation-files.mk", "\n".join(lines))


def emit_registry(catalog_items, selected):
    enum_lines = []
    extern_lines = []
    descriptor_lines = []
    for index, item in enumerate(catalog_items, start=1):
        enum_lines.append(f"    {item['enum']} = {index},")
    for item in selected:
        extern_lines.append(f"LH_INTERNAL bool {item['symbol']}(LHHookBackend *backend, LHPolicyEngine *policy);")
        descriptor_lines.append(f"    {{ {item['enum']}, {item['symbol']} }},")

    header = "\n".join([
        "#ifndef LH_GENERATED_MITIGATION_REGISTRY_H",
        "#define LH_GENERATED_MITIGATION_REGISTRY_H",
        "",
        "#include \"LHModuleRegistry.h\"",
        "",
        "#ifdef __cplusplus",
        "extern \"C\" {",
        "#endif",
        "",
        "typedef enum LHGeneratedModuleID {",
        *enum_lines,
        "} LHGeneratedModuleID;",
        "",
        "LH_INTERNAL extern const LHModuleDescriptor LHGeneratedModuleDescriptors[];",
        "LH_INTERNAL extern const size_t LHGeneratedModuleDescriptorCount;",
        "",
        "#ifdef __cplusplus",
        "}",
        "#endif",
        "",
        "#endif",
        "",
    ])

    source = "\n".join([
        "#include \"LHGeneratedMitigationRegistry.h\"",
        "",
        *extern_lines,
        "",
        "LH_INTERNAL const LHModuleDescriptor LHGeneratedModuleDescriptors[] = {",
        *descriptor_lines,
        "};",
        "",
        "LH_INTERNAL const size_t LHGeneratedModuleDescriptorCount = sizeof(LHGeneratedModuleDescriptors) / sizeof(LHGeneratedModuleDescriptors[0]);",
        "",
    ])

    write_file(ROOT / "core/generated/LHGeneratedMitigationRegistry.h", header)
    write_file(ROOT / "core/generated/LHGeneratedMitigationRegistry.c", source)


def emit_derivation_labels(labels):
    extern_lines = []
    definition_lines = []
    for item in labels:
        extern_lines.append(f"LH_INTERNAL extern const LHDerivationLabel {item['symbol']};")
        definition_lines.extend([
            f"LH_INTERNAL const LHDerivationLabel {item['symbol']} = {{",
            f"    .bytes = {byte_initializer(item['bytes'])}",
            "};",
            "",
        ])

    header = "\n".join([
        "#ifndef LH_GENERATED_DERIVATION_LABELS_H",
        "#define LH_GENERATED_DERIVATION_LABELS_H",
        "",
        "#include \"LHSeed.h\"",
        "",
        "#ifdef __cplusplus",
        "extern \"C\" {",
        "#endif",
        "",
        *extern_lines,
        "",
        "#ifdef __cplusplus",
        "}",
        "#endif",
        "",
        "#endif",
        "",
    ])

    source = "\n".join([
        "#include \"LHGeneratedDerivationLabels.h\"",
        "",
        *definition_lines,
    ])

    write_file(ROOT / "core/generated/LHGeneratedDerivationLabels.h", header)
    write_file(ROOT / "core/generated/LHGeneratedDerivationLabels.c", source)


def emit_generated_config(instance_seed, package_state_parent, package_seed_root_directory, package_root_seed_file):
    has_seed = instance_seed is not None
    seed_bytes = instance_seed if instance_seed is not None else bytes(16)
    header = "\n".join([
        "#ifndef LH_GENERATED_CONFIG_H",
        "#define LH_GENERATED_CONFIG_H",
        "",
        "#include \"LHSeed.h\"",
        "#include \"LHTypes.h\"",
        "",
        "#ifdef __cplusplus",
        "extern \"C\" {",
        "#endif",
        "",
        "LH_INTERNAL extern const bool LHGeneratedConfigHasInstanceSeed;",
        "LH_INTERNAL extern const LHSeed LHGeneratedConfigInstanceSeed;",
        "LH_INTERNAL extern const char LHGeneratedConfigPackageStateParentDirectoryName[];",
        "LH_INTERNAL extern const char LHGeneratedConfigPackageSeedRootDirectoryName[];",
        "LH_INTERNAL extern const char LHGeneratedConfigPackageRootSeedFileName[];",
        "",
        "#ifdef __cplusplus",
        "}",
        "#endif",
        "",
        "#endif",
        "",
    ])

    source = "\n".join([
        "#include \"LHGeneratedConfig.h\"",
        "",
        f"LH_INTERNAL const bool LHGeneratedConfigHasInstanceSeed = {'true' if has_seed else 'false'};",
        "LH_INTERNAL const LHSeed LHGeneratedConfigInstanceSeed = {",
        f"    .bytes = {byte_initializer(seed_bytes)}",
        "};",
        f"LH_INTERNAL const char LHGeneratedConfigPackageStateParentDirectoryName[] = \"{package_state_parent}\";",
        f"LH_INTERNAL const char LHGeneratedConfigPackageSeedRootDirectoryName[] = \"{package_seed_root_directory}\";",
        f"LH_INTERNAL const char LHGeneratedConfigPackageRootSeedFileName[] = \"{package_root_seed_file}\";",
        "",
    ])

    write_file(ROOT / "core/generated/LHGeneratedConfig.h", header)
    write_file(ROOT / "core/generated/LHGeneratedConfig.c", source)


def toggle_helper_script(package_state_parent):
    return "\n".join([
        "#!/bin/sh",
        "set -eu",
        "",
        "ROOT_PREFIX=${ROOT_PREFIX:-/var/jb}",
        "FILTER=\"$ROOT_PREFIX/Library/MobileSubstrate/DynamicLibraries/runtime.plist\"",
        f"STATE_PARENT={package_state_parent}",
        "CONFIG_DIR=\"$ROOT_PREFIX/var/mobile/Library/Preferences/$STATE_PARENT\"",
        "",
        "usage() {",
        "  printf '%s\\n' \"usage: lhctl [list|enable|disable|toggle|clear|menu] [bundle-id]\"",
        "}",
        "",
        "require_root() {",
        "  [ \"${LHCTL_ALLOW_NONROOT:-0}\" = \"1\" ] && return 0",
        "  current_uid=$(id -u 2>/dev/null || printf '1')",
        "  if [ \"$current_uid\" != \"0\" ]; then",
        "    printf '%s\\n' 'lhctl must be run as root; it writes the rootless Substrate filter.'",
        "    exit 1",
        "  fi",
        "}",
        "",
        "valid_bundle() {",
        "  bundle=${1:-}",
        "  [ -n \"$bundle\" ] || return 1",
        "  printf '%s\\n' \"$bundle\" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9.-]*$'",
        "}",
        "",
        "list_bundles() {",
        "  [ -f \"$FILTER\" ] || return 0",
        "  LC_ALL=C sed -n '/<key>Bundles<\\/key>/,/<\\/array>/p' \"$FILTER\" 2>/dev/null | LC_ALL=C sed -n 's/.*<string>\\([^<][^<]*\\)<\\/string>.*/\\1/p'",
        "}",
        "",
        "write_filter_from_file() {",
        "  input=${1:?}",
        "  mkdir -p \"$(dirname \"$FILTER\")\" \"$CONFIG_DIR\"",
        "  tmp=\"$CONFIG_DIR/.runtime.plist.$$\"",
        "  {",
        "    printf '%s\\n' '<?xml version=\"1.0\" encoding=\"UTF-8\"?>'",
        "    printf '%s\\n' '<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">'",
        "    printf '%s\\n' '<plist version=\"1.0\">'",
        "    printf '%s\\n' '<dict>'",
        "    printf '\\t%s\\n' '<key>Filter</key>'",
        "    printf '\\t%s\\n' '<dict>'",
        "    printf '\\t\\t%s\\n' '<key>Bundles</key>'",
        "    printf '\\t\\t%s\\n' '<array>'",
        "    while IFS= read -r bundle; do",
        "      [ -n \"$bundle\" ] || continue",
        "      printf '\\t\\t\\t<string>%s</string>\\n' \"$bundle\"",
        "    done < \"$input\"",
        "    printf '\\t\\t%s\\n' '</array>'",
        "    printf '\\t%s\\n' '</dict>'",
        "    printf '%s\\n' '</dict>'",
        "    printf '%s\\n' '</plist>'",
        "  } > \"$tmp\"",
        "  chmod 644 \"$tmp\"",
        "  mv \"$tmp\" \"$FILTER\"",
        "}",
        "",
        "ensure_filter() {",
        "  [ -f \"$FILTER\" ] && return 0",
        "  mkdir -p \"$CONFIG_DIR\"",
        "  empty=\"$CONFIG_DIR/.bundles.empty.$$\"",
        "  : > \"$empty\"",
        "  write_filter_from_file \"$empty\"",
        "  rm -f \"$empty\"",
        "}",
        "",
        "restart_notice() {",
        "  printf '%s\\n' 'Restart target app(s) for filter changes to apply.'",
        "}",
        "",
        "print_list() {",
        "  ensure_filter",
        "  bundles=$(list_bundles || true)",
        "  if [ -z \"$bundles\" ]; then",
        "    printf '%s\\n' 'No bundles enabled.'",
        "    return 0",
        "  fi",
        "  printf '%s\\n' \"$bundles\"",
        "}",
        "",
        "enable_bundle() {",
        "  bundle=${1:-}",
        "  if ! valid_bundle \"$bundle\"; then",
        "    printf '%s\\n' 'Invalid bundle id.'",
        "    return 2",
        "  fi",
        "  ensure_filter",
        "  tmp=\"$CONFIG_DIR/.bundles.$$\"",
        "  {",
        "    list_bundles | grep -Fvx \"$bundle\" || true",
        "    printf '%s\\n' \"$bundle\"",
        "  } > \"$tmp\"",
        "  write_filter_from_file \"$tmp\"",
        "  rm -f \"$tmp\"",
        "  printf 'Enabled %s\\n' \"$bundle\"",
        "  restart_notice",
        "}",
        "",
        "disable_bundle() {",
        "  bundle=${1:-}",
        "  if ! valid_bundle \"$bundle\"; then",
        "    printf '%s\\n' 'Invalid bundle id.'",
        "    return 2",
        "  fi",
        "  ensure_filter",
        "  tmp=\"$CONFIG_DIR/.bundles.$$\"",
        "  list_bundles | grep -Fvx \"$bundle\" > \"$tmp\" || true",
        "  write_filter_from_file \"$tmp\"",
        "  rm -f \"$tmp\"",
        "  printf 'Disabled %s\\n' \"$bundle\"",
        "  restart_notice",
        "}",
        "",
        "toggle_bundle() {",
        "  bundle=${1:-}",
        "  if ! valid_bundle \"$bundle\"; then",
        "    printf '%s\\n' 'Invalid bundle id.'",
        "    return 2",
        "  fi",
        "  ensure_filter",
        "  if list_bundles | grep -Fxq \"$bundle\"; then",
        "    disable_bundle \"$bundle\"",
        "  else",
        "    enable_bundle \"$bundle\"",
        "  fi",
        "}",
        "",
        "clear_bundles() {",
        "  ensure_filter",
        "  tmp=\"$CONFIG_DIR/.bundles.$$\"",
        "  : > \"$tmp\"",
        "  write_filter_from_file \"$tmp\"",
        "  rm -f \"$tmp\"",
        "  printf '%s\\n' 'Disabled all bundles.'",
        "  restart_notice",
        "}",
        "",
        "run_menu() {",
        "  while :; do",
        "    printf '\\n%s\\n' 'Loupehole bundle toggle'",
        "    printf '%s\\n' '1) List enabled bundles'",
        "    printf '%s\\n' '2) Enable bundle'",
        "    printf '%s\\n' '3) Disable bundle'",
        "    printf '%s\\n' '4) Toggle bundle'",
        "    printf '%s\\n' '5) Disable all bundles'",
        "    printf '%s\\n' '6) Quit'",
        "    printf '%s' 'Choice: '",
        "    IFS= read -r choice || exit 0",
        "    case \"$choice\" in",
        "      1) print_list ;;",
        "      2)",
        "        printf '%s' 'Bundle ID: '",
        "        IFS= read -r bundle || exit 0",
        "        enable_bundle \"$bundle\" || true",
        "        ;;",
        "      3)",
        "        printf '%s' 'Bundle ID: '",
        "        IFS= read -r bundle || exit 0",
        "        disable_bundle \"$bundle\" || true",
        "        ;;",
        "      4)",
        "        printf '%s' 'Bundle ID: '",
        "        IFS= read -r bundle || exit 0",
        "        toggle_bundle \"$bundle\" || true",
        "        ;;",
        "      5) clear_bundles ;;",
        "      6|q|quit|exit) exit 0 ;;",
        "      *) printf '%s\\n' 'Unknown choice.' ;;",
        "    esac",
        "  done",
        "}",
        "",
        "command=${1:-menu}",
        "case \"$command\" in",
        "  -h|--help|help) usage; exit 0 ;;",
        "esac",
        "require_root",
        "case \"$command\" in",
        "  menu) run_menu ;;",
        "  list) print_list ;;",
        "  enable) shift; enable_bundle \"${1:-}\" ;;",
        "  disable) shift; disable_bundle \"${1:-}\" ;;",
        "  toggle) shift; toggle_bundle \"${1:-}\" ;;",
        "  clear) clear_bundles ;;",
        "  *) usage; exit 2 ;;",
        "esac",
        "",
    ])


def emit_package_layout(package_state_parent, package_seed_root_directory, package_root_seed_file):
    layout_dir = ROOT / "packages/tweak/generated/package-layout"
    if layout_dir.exists():
        shutil.rmtree(layout_dir)

    write_executable(layout_dir / "DEBIAN/preinst", "\n".join([
        "#!/bin/sh",
        "set -eu",
        "",
        "case \"${1:-}\" in",
        "  install|upgrade)",
        "    ;;",
        "esac",
        "",
        "exit 0",
        "",
    ]))

    write_executable(layout_dir / "DEBIAN/postinst", "\n".join([
        "#!/bin/sh",
        "set -eu",
        "",
        "ROOT_PREFIX=${ROOT_PREFIX:-/var/jb}",
        f"STATE_PARENT={package_state_parent}",
        f"SEED_ROOT_DIR={package_seed_root_directory}",
        f"ROOT_SEED_FILE={package_root_seed_file}",
        "",
        "support_dir=\"$ROOT_PREFIX/var/mobile/Library/Application Support/$STATE_PARENT\"",
        "cache_dir=\"$ROOT_PREFIX/var/mobile/Library/Caches/$STATE_PARENT\"",
        "config_dir=\"$ROOT_PREFIX/var/mobile/Library/Preferences/$STATE_PARENT\"",
        "seed_root_dir=\"$support_dir/$SEED_ROOT_DIR\"",
        "root_seed_file=\"$seed_root_dir/$ROOT_SEED_FILE\"",
        "",
        "case \"${1:-}\" in",
        "  configure)",
        "    mkdir -p \"$support_dir\" \"$cache_dir\" \"$config_dir\" \"$seed_root_dir\"",
        "    chmod 700 \"$support_dir\" \"$cache_dir\" \"$config_dir\" \"$seed_root_dir\"",
        "    if [ ! -f \"$root_seed_file\" ]; then",
        "      umask 077",
        "      if dd if=/dev/urandom of=\"$root_seed_file\" bs=16 count=1 >/dev/null 2>&1; then",
        "        chmod 600 \"$root_seed_file\"",
        "      else",
        "        rm -f \"$root_seed_file\"",
        "      fi",
        "    fi",
        "    if command -v chown >/dev/null 2>&1; then",
        "      chown mobile:mobile \"$support_dir\" \"$cache_dir\" \"$config_dir\" \"$seed_root_dir\" \"$root_seed_file\" 2>/dev/null || true",
        "    fi",
        "    ;;",
        "esac",
        "",
        "exit 0",
        "",
    ]))

    write_executable(layout_dir / "DEBIAN/prerm", "\n".join([
        "#!/bin/sh",
        "set -eu",
        "",
        "ROOT_PREFIX=${ROOT_PREFIX:-/var/jb}",
        "filter=\"$ROOT_PREFIX/Library/MobileSubstrate/DynamicLibraries/runtime.plist\"",
        "",
        "write_disabled_filter() {",
        "  if [ ! -d \"$(dirname \"$filter\")\" ]; then",
        "    return 0",
        "  fi",
        "  cat >\"$filter\" <<'PLIST'",
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
        "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">",
        "<plist version=\"1.0\">",
        "<dict>",
        "\t<key>Filter</key>",
        "\t<dict>",
        "\t\t<key>Bundles</key>",
        "\t\t<array/>",
        "\t</dict>",
        "</dict>",
        "</plist>",
        "PLIST",
        "}",
        "",
        "case \"${1:-}\" in",
        "  remove|deconfigure)",
        "    write_disabled_filter",
        "    ;;",
        "  upgrade)",
        "    ;;",
        "esac",
        "",
        "exit 0",
        "",
    ]))

    write_executable(layout_dir / "DEBIAN/postrm", "\n".join([
        "#!/bin/sh",
        "set -eu",
        "",
        "ROOT_PREFIX=${ROOT_PREFIX:-/var/jb}",
        f"STATE_PARENT={package_state_parent}",
        "",
        "dynamic_dir=\"$ROOT_PREFIX/Library/MobileSubstrate/DynamicLibraries\"",
        "support_dir=\"$ROOT_PREFIX/var/mobile/Library/Application Support/$STATE_PARENT\"",
        "cache_dir=\"$ROOT_PREFIX/var/mobile/Library/Caches/$STATE_PARENT\"",
        "config_dir=\"$ROOT_PREFIX/var/mobile/Library/Preferences/$STATE_PARENT\"",
        "preference_bundle=\"$ROOT_PREFIX/Library/PreferenceBundles/LoupeholePreferences.bundle\"",
        "preference_loader=\"$ROOT_PREFIX/Library/PreferenceLoader/Preferences/Loupehole.plist\"",
        "launch_helper=\"$ROOT_PREFIX/Library/LaunchDaemons/com.loupehole.runtime.plist\"",
        "toggle_helper=\"$ROOT_PREFIX/usr/bin/lhctl\"",
        "",
        "case \"${1:-}\" in",
        "  remove|purge)",
        "    rm -f \"$dynamic_dir/runtime.dylib\" \"$dynamic_dir/runtime.plist\" \"$launch_helper\" \"$toggle_helper\"",
        "    rm -rf \"$support_dir\" \"$cache_dir\" \"$config_dir\" \"$preference_bundle\" \"$preference_loader\"",
        "    ;;",
        "  upgrade)",
        "    ;;",
        "esac",
        "",
        "exit 0",
        "",
    ]))

    for relative in (
        "var/mobile/Library/Application Support",
        "var/mobile/Library/Caches",
        "var/mobile/Library/Preferences",
    ):
        write_file(layout_dir / relative / package_state_parent / ".keep", "\n")
    write_file(layout_dir / "var/mobile/Library/Application Support" / package_state_parent / package_seed_root_directory / ".keep", "\n")
    write_executable(layout_dir / "usr/bin/lhctl", toggle_helper_script(package_state_parent))


def emit_policy_value_registry(selected_values):
    enum_lines = []
    extern_lines = []
    descriptor_lines = []
    for index, item in enumerate(selected_values, start=1):
        enum_lines.append(f"    {item['enum']} = {index},")
        extern_lines.append(f"LH_INTERNAL bool {item['resolver']}(const LHPolicyEngine *engine, const LHPolicyValueRequest *request, LHPolicyValueResponse *response);")
        descriptor_lines.append(f"    {{ {item['enum']}, {item['kindSymbol']}, {item['resolver']} }},")

    header = "\n".join([
        "#ifndef LH_GENERATED_POLICY_VALUE_REGISTRY_H",
        "#define LH_GENERATED_POLICY_VALUE_REGISTRY_H",
        "",
        "#include \"LHPolicyEngine.h\"",
        "#include \"LHPolicyValue.h\"",
        "",
        "#ifdef __cplusplus",
        "extern \"C\" {",
        "#endif",
        "",
        "typedef enum LHGeneratedPolicyValueID {",
        *enum_lines,
        "} LHGeneratedPolicyValueID;",
        "",
        "LH_INTERNAL extern const LHPolicyValueDescriptor LHGeneratedPolicyValueDescriptors[];",
        "LH_INTERNAL extern const size_t LHGeneratedPolicyValueDescriptorCount;",
        "",
        "#ifdef __cplusplus",
        "}",
        "#endif",
        "",
        "#endif",
        "",
    ])

    source = "\n".join([
        "#include \"LHGeneratedPolicyValueRegistry.h\"",
        "",
        *extern_lines,
        "",
        "LH_INTERNAL const LHPolicyValueDescriptor LHGeneratedPolicyValueDescriptors[] = {",
        *descriptor_lines,
        "};",
        "",
        "LH_INTERNAL const size_t LHGeneratedPolicyValueDescriptorCount = sizeof(LHGeneratedPolicyValueDescriptors) / sizeof(LHGeneratedPolicyValueDescriptors[0]);",
        "",
    ])

    write_file(ROOT / "core/generated/LHGeneratedPolicyValueRegistry.h", header)
    write_file(ROOT / "core/generated/LHGeneratedPolicyValueRegistry.c", source)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--values", required=True)
    parser.add_argument("--selection", required=True)
    args = parser.parse_args()

    catalog = load_json(ROOT / args.catalog)
    value_catalog = load_json(ROOT / args.values)
    selection = load_json(ROOT / args.selection)
    instance_seed = parse_uuid_bytes(selection.get("instanceSeed"), "selection.instanceSeed")
    package_state_parent = package_state_parent_name(instance_seed)
    package_seed_root_directory = package_seed_root_directory_name(instance_seed)
    package_root_seed_file = package_root_seed_file_name(instance_seed)
    mitigations = normalize_catalog(catalog)
    policy_values = normalize_policy_values(value_catalog)
    selected, selected_values = validate_selection(selection, mitigations, policy_values)
    label_sources = selected_source_paths(selected, selected_values) + core_derivation_label_source_paths()
    derivation_labels = discover_derivation_labels(list(dict.fromkeys(label_sources)), instance_seed)
    emit_make_fragment(selected, selected_values)
    emit_registry(mitigations.values(), selected)
    emit_generated_config(instance_seed, package_state_parent, package_seed_root_directory, package_root_seed_file)
    emit_derivation_labels(derivation_labels)
    emit_policy_value_registry(selected_values)
    emit_package_layout(package_state_parent, package_seed_root_directory, package_root_seed_file)


if __name__ == "__main__":
    main()
