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
PACKAGE_POLICY_FILE_NAMESPACE = b"lh.package-policy-file.v1\0"
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


def package_policy_file_name(instance_seed):
    return generated_hex_name(PACKAGE_POLICY_FILE_NAMESPACE, instance_seed)


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
    for item in catalog_items:
        enum_lines.append(f"    {item['enum']} = {item['moduleID']},")
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


def emit_generated_config(instance_seed, package_state_parent, package_seed_root_directory, package_root_seed_file, package_policy_file):
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
        "LH_INTERNAL extern const char LHGeneratedConfigPackagePolicyFileName[];",
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
        f"LH_INTERNAL const char LHGeneratedConfigPackagePolicyFileName[] = \"{package_policy_file}\";",
        "",
    ])

    write_file(ROOT / "core/generated/LHGeneratedConfig.h", header)
    write_file(ROOT / "core/generated/LHGeneratedConfig.c", source)


def toggle_helper_script(package_state_parent, package_policy_file, selected):
    all_modules = ",".join(str(item["moduleID"]) for item in selected)
    module_id_cases = []
    valid_module_cases = []
    module_list_lines = []
    for item in selected:
        module_id = str(item["moduleID"])
        module_id_cases.append(f"    {item['id']}|{module_id}) printf '%s\\n' '{module_id}'; return 0 ;;")
        valid_module_cases.append(f"    {module_id}) return 0 ;;")
        module_list_lines.append(f"  printf '%s\\n' '{module_id} {item['id']}'")

    return "\n".join([
        "#!/bin/sh",
        "set -eu",
        "",
        "ROOT_PREFIX=${ROOT_PREFIX:-/var/jb}",
        "FILTER=\"$ROOT_PREFIX/Library/MobileSubstrate/DynamicLibraries/runtime.plist\"",
        "APP_FILTER_BUNDLE=com.apple.UIKit",
        f"STATE_PARENT={package_state_parent}",
        f"POLICY_FILE={package_policy_file}",
        f"DEFAULT_MODULES={all_modules}",
        "CONFIG_DIR=\"$ROOT_PREFIX/var/mobile/Library/Preferences/$STATE_PARENT\"",
        "POLICY=\"$CONFIG_DIR/$POLICY_FILE\"",
        "",
        "usage() {",
        "  cat <<'USAGE'",
        "usage:",
        "  lhctl list",
        "  lhctl status [bundle-id]",
        "  lhctl enable|disable|toggle <bundle-id>",
        "  lhctl clear",
        "  lhctl set <bundle-id> enabled <on|off>",
        "  lhctl set <bundle-id> scope <per-app-install|per-app|per-vendor-group|per-shared-app-group|manual-linked-group>",
        "  lhctl set <bundle-id> mitigations <all|none|module-id...>",
        "  lhctl default enabled <on|off>",
        "  lhctl default scope <per-app-install|per-app|per-vendor-group|per-shared-app-group|manual-linked-group>",
        "  lhctl default mitigations <all|none|module-id...>",
        "  lhctl mitigations|scopes|menu",
        "USAGE",
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
        "  candidate_bundle=${1:-}",
        "  [ -n \"$candidate_bundle\" ] || return 1",
        "  printf '%s\\n' \"$candidate_bundle\" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9.-]*$'",
        "}",
        "",
        "system_bundle() {",
        "  case \"${1:-}\" in",
        "    com.apple|com.apple.*) return 0 ;;",
        "    *) return 1 ;;",
        "  esac",
        "}",
        "",
        "require_configurable_bundle() {",
        "  target_bundle=${1:-}",
        "  if ! valid_bundle \"$target_bundle\"; then",
        "    printf '%s\\n' 'Invalid bundle id.'",
        "    return 2",
        "  fi",
        "  if system_bundle \"$target_bundle\"; then",
        "    printf '%s\\n' 'System bundles are always excluded.'",
        "    return 2",
        "  fi",
        "}",
        "",
        "valid_module_id() {",
        "  case \"${1:-}\" in",
        *valid_module_cases,
        "    *) return 1 ;;",
        "  esac",
        "}",
        "",
        "module_id() {",
        "  case \"${1:-}\" in",
        *module_id_cases,
        "    *)",
        "      if valid_module_id \"${1:-}\"; then",
        "        printf '%s\\n' \"$1\"",
        "        return 0",
        "      fi",
        "      return 1",
        "      ;;",
        "  esac",
        "}",
        "",
        "print_mitigations() {",
        *module_list_lines,
        "}",
        "",
        "bool_value() {",
        "  case \"${1:-}\" in",
        "    on|enable|enabled|yes|true|1) printf '%s\\n' 1 ;;",
        "    off|disable|disabled|no|false|0) printf '%s\\n' 0 ;;",
        "    *) return 1 ;;",
        "  esac",
        "}",
        "",
        "scope_value() {",
        "  case \"${1:-}\" in",
        "    per-app-install|app-install|install|0) printf '%s\\n' 0 ;;",
        "    per-app|app|1) printf '%s\\n' 1 ;;",
        "    per-vendor-group|vendor|vendor-group|2) printf '%s\\n' 2 ;;",
        "    per-shared-app-group|shared-app-group|app-group|3) printf '%s\\n' 3 ;;",
        "    manual-linked-group|manual|linked|4) printf '%s\\n' 4 ;;",
        "    *) return 1 ;;",
        "  esac",
        "}",
        "",
        "enabled_label() { [ \"${1:-0}\" = \"1\" ] && printf '%s\\n' on || printf '%s\\n' off; }",
        "",
        "scope_label() {",
        "  case \"${1:-}\" in",
        "    0) printf '%s\\n' per-app-install ;;",
        "    1) printf '%s\\n' per-app ;;",
        "    2) printf '%s\\n' per-vendor-group ;;",
        "    3) printf '%s\\n' per-shared-app-group ;;",
        "    4) printf '%s\\n' manual-linked-group ;;",
        "    *) printf '%s\\n' unknown ;;",
        "  esac",
        "}",
        "",
        "normalize_modules() {",
        "  [ \"$#\" -gt 0 ] || return 1",
        "  case \"$1\" in",
        "    all) printf '0|\\n'; return 0 ;;",
        "    none) printf '1|\\n'; return 0 ;;",
        "  esac",
        "  out=",
        "  for raw in \"$@\"; do",
        "    for token in $(printf '%s\\n' \"$raw\" | tr ',' ' '); do",
        "      [ -n \"$token\" ] || continue",
        "      id=$(module_id \"$token\") || return 1",
        "      case \",$out,\" in",
        "        *,$id,*) ;;",
        "        *) out=${out:+$out,}$id ;;",
        "      esac",
        "    done",
        "  done",
        "  [ -n \"$out\" ] || return 1",
        "  printf '1|%s\\n' \"$out\"",
        "}",
        "",
        "modules_label() {",
        "  has=${1:-0}",
        "  modules=${2:-}",
        "  if [ \"$has\" = \"0\" ]; then",
        "    printf '%s\\n' all",
        "  elif [ -z \"$modules\" ]; then",
        "    printf '%s\\n' none",
        "  else",
        "    printf '%s\\n' \"$modules\"",
        "  fi",
        "}",
        "",
        "list_bundles() {",
        "  [ -f \"$FILTER\" ] || return 0",
        "  LC_ALL=C sed -n '/<key>Bundles<\\/key>/,/<\\/array>/p' \"$FILTER\" 2>/dev/null | LC_ALL=C sed -n 's/.*<string>\\([^<][^<]*\\)<\\/string>.*/\\1/p'",
        "}",
        "",
        "policy_bundles_by_enabled() {",
        "  wanted=${1:?}",
        "  ensure_policy",
        "  while IFS= read -r policy_line || [ -n \"$policy_line\" ]; do",
        "    if [ \"$(field \"$policy_line\" 1)\" = \"B\" ] && [ \"$(field \"$policy_line\" 3)\" = \"$wanted\" ]; then",
        "      policy_bundle=$(field \"$policy_line\" 2)",
        "      if valid_bundle \"$policy_bundle\" && ! system_bundle \"$policy_bundle\"; then",
        "        printf '%s\\n' \"$policy_bundle\"",
        "      fi",
        "    fi",
        "  done < \"$POLICY\"",
        "}",
        "",
        "write_policy_from_file() {",
        "  input=${1:?}",
        "  mkdir -p \"$CONFIG_DIR\"",
        "  tmp=\"$CONFIG_DIR/.$POLICY_FILE.out.$$\"",
        "  cp \"$input\" \"$tmp\"",
        "  chmod 644 \"$tmp\"",
        "  mv \"$tmp\" \"$POLICY\"",
        "}",
        "",
        "ensure_policy() {",
        "  mkdir -p \"$CONFIG_DIR\"",
        "  if [ ! -f \"$POLICY\" ]; then",
        "    tmp=\"$CONFIG_DIR/.$POLICY_FILE.$$\"",
        "    printf 'D|0|0|0|\\n' > \"$tmp\"",
        "    chmod 644 \"$tmp\"",
        "    mv \"$tmp\" \"$POLICY\"",
        "    return 0",
        "  fi",
        "  if ! grep -q '^D|' \"$POLICY\" 2>/dev/null; then",
        "    tmp=\"$CONFIG_DIR/.$POLICY_FILE.$$\"",
        "    { printf 'D|0|0|0|\\n'; cat \"$POLICY\"; } > \"$tmp\"",
        "    write_policy_from_file \"$tmp\"",
        "    rm -f \"$tmp\"",
        "  fi",
        "}",
        "",
        "field() {",
        "  line_value=${1-}",
        "  field_number=${2:-0}",
        "  old_ifs=$IFS",
        "  IFS='|'",
        "  set -- $line_value",
        "  IFS=$old_ifs",
        "  eval \"printf '%s\\\\n' \\\"\\${$field_number:-}\\\"\"",
        "}",
        "",
        "default_line() {",
        "  ensure_policy",
        "  found_line=",
        "  while IFS= read -r policy_line || [ -n \"$policy_line\" ]; do",
        "    case \"$policy_line\" in",
        "      D\\|*) found_line=$policy_line ;;",
        "    esac",
        "  done < \"$POLICY\"",
        "  [ -n \"$found_line\" ] && printf '%s\\n' \"$found_line\"",
        "}",
        "",
        "bundle_line() {",
        "  ensure_policy",
        "  query_bundle=${1:?}",
        "  found_line=",
        "  while IFS= read -r policy_line || [ -n \"$policy_line\" ]; do",
        "    if [ \"$(field \"$policy_line\" 1)\" = \"B\" ] && [ \"$(field \"$policy_line\" 2)\" = \"$query_bundle\" ]; then",
        "      found_line=$policy_line",
        "    fi",
        "  done < \"$POLICY\"",
        "  [ -n \"$found_line\" ] && printf '%s\\n' \"$found_line\"",
        "}",
        "",
        "default_fields() {",
        "  line=$(default_line)",
        "  printf '%s|%s|%s|%s\\n' \"$(field \"$line\" 2)\" \"$(field \"$line\" 3)\" \"$(field \"$line\" 4)\" \"$(field \"$line\" 5)\"",
        "}",
        "",
        "effective_bundle_line() {",
        "  query_bundle=${1:?}",
        "  line=$(bundle_line \"$query_bundle\" || true)",
        "  if [ -n \"$line\" ]; then",
        "    printf '%s\\n' \"$line\"",
        "  else",
        "    printf 'B|%s|%s\\n' \"$query_bundle\" \"$(default_fields)\"",
        "  fi",
        "}",
        "",
        "default_enabled() {",
        "  line=$(default_line)",
        "  [ \"$(field \"$line\" 2)\" = \"1\" ]",
        "}",
        "",
        "write_default_line() {",
        "  ensure_policy",
        "  enabled=$1; scope=$2; has_modules=$3; modules=$4",
        "  tmp=\"$CONFIG_DIR/.policy.$$\"",
        "  {",
        "    printf 'D|%s|%s|%s|%s\\n' \"$enabled\" \"$scope\" \"$has_modules\" \"$modules\"",
        "    while IFS= read -r policy_line || [ -n \"$policy_line\" ]; do",
        "      case \"$policy_line\" in",
        "        D\\|*) ;;",
        "        *) printf '%s\\n' \"$policy_line\" ;;",
        "      esac",
        "    done < \"$POLICY\"",
        "  } > \"$tmp\"",
        "  write_policy_from_file \"$tmp\"",
        "  rm -f \"$tmp\"",
        "}",
        "",
        "write_bundle_line() {",
        "  ensure_policy",
        "  policy_bundle=$1; enabled=$2; scope=$3; has_modules=$4; modules=$5",
        "  tmp=\"$CONFIG_DIR/.policy.$$\"",
        "  {",
        "    while IFS= read -r policy_line || [ -n \"$policy_line\" ]; do",
        "      if [ \"$(field \"$policy_line\" 1)\" = \"B\" ] && [ \"$(field \"$policy_line\" 2)\" = \"$policy_bundle\" ]; then",
        "        continue",
        "      fi",
        "      printf '%s\\n' \"$policy_line\"",
        "    done < \"$POLICY\"",
        "    printf 'B|%s|%s|%s|%s|%s\\n' \"$policy_bundle\" \"$enabled\" \"$scope\" \"$has_modules\" \"$modules\"",
        "  } > \"$tmp\"",
        "  write_policy_from_file \"$tmp\"",
        "  rm -f \"$tmp\"",
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
        "    while IFS= read -r filter_bundle; do",
        "      [ -n \"$filter_bundle\" ] || continue",
        "      printf '\\t\\t\\t<string>%s</string>\\n' \"$filter_bundle\"",
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
        "refresh_filter() {",
        "  ensure_policy",
        "  tmp=\"$CONFIG_DIR/.bundles.$$\"",
        "  if default_enabled; then",
        "    printf '%s\\n' \"$APP_FILTER_BUNDLE\" > \"$tmp\"",
        "  else",
        "    policy_bundles_by_enabled 1 > \"$tmp\"",
        "  fi",
        "  write_filter_from_file \"$tmp\"",
        "  rm -f \"$tmp\"",
        "}",
        "",
        "ensure_filter() {",
        "  [ -f \"$FILTER\" ] && return 0",
        "  refresh_filter",
        "}",
        "",
        "restart_notice() {",
        "  printf '%s\\n' 'Restart target app(s) for filter changes to apply.'",
        "}",
        "",
        "print_policy_line() {",
        "  label=$1",
        "  line=$2",
        "  if [ \"$(field \"$line\" 1)\" = \"D\" ]; then",
        "    base=1",
        "  else",
        "    base=2",
        "  fi",
        "  enabled=$(field \"$line\" $((base + 1)))",
        "  scope=$(field \"$line\" $((base + 2)))",
        "  has_modules=$(field \"$line\" $((base + 3)))",
        "  modules=$(field \"$line\" $((base + 4)))",
        "  printf '%s\\n' \"$label\"",
        "  printf '  enabled: %s\\n' \"$(enabled_label \"$enabled\")\"",
        "  printf '  scope: %s\\n' \"$(scope_label \"$scope\")\"",
        "  printf '  mitigations: %s\\n' \"$(modules_label \"$has_modules\" \"$modules\")\"",
        "}",
        "",
        "print_list() {",
        "  ensure_filter",
        "  ensure_policy",
        "  if default_enabled; then",
        "    printf '%s\\n' 'Default profile: on'",
        "    disabled=$(policy_bundles_by_enabled 0 || true)",
        "    if [ -n \"$disabled\" ]; then",
        "      printf '%s\\n' 'Disabled overrides:'",
        "      printf '%s\\n' \"$disabled\"",
        "    fi",
        "    return 0",
        "  fi",
        "  enabled=$(policy_bundles_by_enabled 1 || true)",
        "  if [ -z \"$enabled\" ]; then",
        "    printf '%s\\n' 'No bundles enabled.'",
        "    return 0",
        "  fi",
        "  printf '%s\\n' \"$enabled\"",
        "}",
        "",
        "print_status() {",
        "  ensure_filter",
        "  ensure_policy",
        "  target_bundle=${1:-}",
        "  if [ -z \"$target_bundle\" ]; then",
        "    print_policy_line default \"$(default_line)\"",
        "    return 0",
        "  fi",
        "  if ! valid_bundle \"$target_bundle\"; then",
        "    printf '%s\\n' 'Invalid bundle id.'",
        "    return 2",
        "  fi",
        "  if system_bundle \"$target_bundle\"; then",
        "    printf '%s\\n' 'effective: disabled'",
        "    printf '%s\\n' 'reason: system bundle'",
        "    return 0",
        "  fi",
        "  line=$(effective_bundle_line \"$target_bundle\")",
        "  if [ \"$(field \"$line\" 3)\" = \"1\" ]; then",
        "    printf 'effective: enabled\\n'",
        "  else",
        "    printf 'effective: disabled\\n'",
        "  fi",
        "  if default_enabled; then",
        "    printf 'filter: %s\\n' \"$APP_FILTER_BUNDLE\"",
        "  elif list_bundles | grep -Fxq \"$target_bundle\"; then",
        "    printf 'filter: direct bundle\\n'",
        "  else",
        "    printf 'filter: disabled\\n'",
        "  fi",
        "  print_policy_line \"$target_bundle\" \"$line\"",
        "}",
        "",
        "enable_bundle() {",
        "  target_bundle=${1:-}",
        "  require_configurable_bundle \"$target_bundle\" || return $?",
        "  ensure_policy",
        "  line=$(effective_bundle_line \"$target_bundle\")",
        "  write_bundle_line \"$target_bundle\" 1 \"$(field \"$line\" 4)\" \"$(field \"$line\" 5)\" \"$(field \"$line\" 6)\"",
        "  refresh_filter",
        "  printf 'Enabled %s\\n' \"$target_bundle\"",
        "  restart_notice",
        "}",
        "",
        "disable_bundle() {",
        "  target_bundle=${1:-}",
        "  require_configurable_bundle \"$target_bundle\" || return $?",
        "  ensure_policy",
        "  line=$(effective_bundle_line \"$target_bundle\")",
        "  write_bundle_line \"$target_bundle\" 0 \"$(field \"$line\" 4)\" \"$(field \"$line\" 5)\" \"$(field \"$line\" 6)\"",
        "  refresh_filter",
        "  printf 'Disabled %s\\n' \"$target_bundle\"",
        "  restart_notice",
        "}",
        "",
        "toggle_bundle() {",
        "  target_bundle=${1:-}",
        "  require_configurable_bundle \"$target_bundle\" || return $?",
        "  ensure_policy",
        "  line=$(effective_bundle_line \"$target_bundle\")",
        "  if [ \"$(field \"$line\" 3)\" = \"1\" ]; then",
        "    disable_bundle \"$target_bundle\"",
        "  else",
        "    enable_bundle \"$target_bundle\"",
        "  fi",
        "}",
        "",
        "clear_bundles() {",
        "  ensure_policy",
        "  line=$(default_line)",
        "  write_default_line 0 \"$(field \"$line\" 3)\" \"$(field \"$line\" 4)\" \"$(field \"$line\" 5)\"",
        "  tmp=\"$CONFIG_DIR/.policy.$$\"",
        "  {",
        "    while IFS= read -r policy_line || [ -n \"$policy_line\" ]; do",
        "      if [ \"$(field \"$policy_line\" 1)\" = \"B\" ]; then",
        "        printf 'B|%s|0|%s|%s|%s\\n' \"$(field \"$policy_line\" 2)\" \"$(field \"$policy_line\" 4)\" \"$(field \"$policy_line\" 5)\" \"$(field \"$policy_line\" 6)\"",
        "      else",
        "        printf '%s\\n' \"$policy_line\"",
        "      fi",
        "    done < \"$POLICY\"",
        "  } > \"$tmp\"",
        "  write_policy_from_file \"$tmp\"",
        "  rm -f \"$tmp\"",
        "  refresh_filter",
        "  printf '%s\\n' 'Disabled all bundles.'",
        "  restart_notice",
        "}",
        "",
        "set_default_setting() {",
        "  setting=${1:-}; shift || true",
        "  line=$(default_line)",
        "  enabled=$(field \"$line\" 2)",
        "  scope=$(field \"$line\" 3)",
        "  has_modules=$(field \"$line\" 4)",
        "  modules=$(field \"$line\" 5)",
        "  case \"$setting\" in",
        "    enabled)",
        "      enabled=$(bool_value \"${1:-}\") || { printf '%s\\n' 'Invalid enabled value.'; return 2; }",
        "      ;;",
        "    scope)",
        "      scope=$(scope_value \"${1:-}\") || { printf '%s\\n' 'Invalid scope.'; return 2; }",
        "      ;;",
        "    mitigations)",
        "      modules_result=$(normalize_modules \"$@\") || { printf '%s\\n' 'Invalid mitigation list.'; return 2; }",
        "      has_modules=${modules_result%%|*}",
        "      modules=${modules_result#*|}",
        "      ;;",
        "    status|'')",
        "      print_policy_line default \"$line\"",
        "      return 0",
        "      ;;",
        "    *) printf '%s\\n' 'Unknown default setting.'; return 2 ;;",
        "  esac",
        "  write_default_line \"$enabled\" \"$scope\" \"$has_modules\" \"$modules\"",
        "  refresh_filter",
        "  printf '%s\\n' 'Updated default policy.'",
        "  restart_notice",
        "}",
        "",
        "set_bundle_setting() {",
        "  target_bundle=${1:-}; setting=${2:-}",
        "  shift 2 || true",
        "  require_configurable_bundle \"$target_bundle\" || return $?",
        "  line=$(effective_bundle_line \"$target_bundle\")",
        "  enabled=$(field \"$line\" 3)",
        "  scope=$(field \"$line\" 4)",
        "  has_modules=$(field \"$line\" 5)",
        "  modules=$(field \"$line\" 6)",
        "  case \"$setting\" in",
        "    enabled)",
        "      enabled=$(bool_value \"${1:-}\") || { printf '%s\\n' 'Invalid enabled value.'; return 2; }",
        "      ;;",
        "    scope)",
        "      scope=$(scope_value \"${1:-}\") || { printf '%s\\n' 'Invalid scope.'; return 2; }",
        "      ;;",
        "    mitigations)",
        "      modules_result=$(normalize_modules \"$@\") || { printf '%s\\n' 'Invalid mitigation list.'; return 2; }",
        "      has_modules=${modules_result%%|*}",
        "      modules=${modules_result#*|}",
        "      ;;",
        "    *) printf '%s\\n' 'Unknown bundle setting.'; return 2 ;;",
        "  esac",
        "  write_bundle_line \"$target_bundle\" \"$enabled\" \"$scope\" \"$has_modules\" \"$modules\"",
        "  refresh_filter",
        "  printf 'Updated %s\\n' \"$target_bundle\"",
        "  restart_notice",
        "}",
        "",
        "run_menu() {",
        "  while :; do",
        "    printf '\\n%s\\n' 'Loupehole settings'",
        "    printf '%s\\n' '1) List enabled bundles'",
        "    printf '%s\\n' '2) Bundle status'",
        "    printf '%s\\n' '3) Enable bundle'",
        "    printf '%s\\n' '4) Disable bundle'",
        "    printf '%s\\n' '5) Set bundle scope'",
        "    printf '%s\\n' '6) Set bundle mitigations'",
        "    printf '%s\\n' '7) Default status'",
        "    printf '%s\\n' '8) Disable all bundles'",
        "    printf '%s\\n' '9) Quit'",
        "    printf '%s' 'Choice: '",
        "    IFS= read -r choice || exit 0",
        "    case \"$choice\" in",
        "      1) print_list ;;",
        "      2)",
        "        printf '%s' 'Bundle ID: '",
        "        IFS= read -r menu_bundle || exit 0",
        "        print_status \"$menu_bundle\" || true",
        "        ;;",
        "      3)",
        "        printf '%s' 'Bundle ID: '",
        "        IFS= read -r menu_bundle || exit 0",
        "        enable_bundle \"$menu_bundle\" || true",
        "        ;;",
        "      4)",
        "        printf '%s' 'Bundle ID: '",
        "        IFS= read -r menu_bundle || exit 0",
        "        disable_bundle \"$menu_bundle\" || true",
        "        ;;",
        "      5)",
        "        printf '%s' 'Bundle ID: '",
        "        IFS= read -r menu_bundle || exit 0",
        "        printf '%s' 'Scope: '",
        "        IFS= read -r value || exit 0",
        "        set_bundle_setting \"$menu_bundle\" scope \"$value\" || true",
        "        ;;",
        "      6)",
        "        printf '%s' 'Bundle ID: '",
        "        IFS= read -r menu_bundle || exit 0",
        "        printf '%s' 'Mitigations: '",
        "        IFS= read -r value || exit 0",
        "        set_bundle_setting \"$menu_bundle\" mitigations \"$value\" || true",
        "        ;;",
        "      7) print_status ;;",
        "      8) clear_bundles ;;",
        "      9|q|quit|exit) exit 0 ;;",
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
        "  status) shift; print_status \"${1:-}\" ;;",
        "  enable) shift; enable_bundle \"${1:-}\" ;;",
        "  disable) shift; disable_bundle \"${1:-}\" ;;",
        "  toggle) shift; toggle_bundle \"${1:-}\" ;;",
        "  clear) clear_bundles ;;",
        "  set) shift; set_bundle_setting \"$@\" ;;",
        "  default)",
        "    shift",
        "    if [ \"$#\" -eq 0 ]; then",
        "      set_default_setting status",
        "    else",
        "      set_default_setting \"$@\"",
        "    fi",
        "    ;;",
        "  mitigations) print_mitigations ;;",
        "  scopes) printf '%s\\n' 'per-app-install per-app per-vendor-group per-shared-app-group manual-linked-group' ;;",
        "  *) usage; exit 2 ;;",
        "esac",
        "",
    ])


def emit_package_layout(package_state_parent, package_seed_root_directory, package_root_seed_file, package_policy_file, selected):
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
        f"POLICY_FILE={package_policy_file}",
        "",
        "support_dir=\"$ROOT_PREFIX/var/mobile/Library/Application Support/$STATE_PARENT\"",
        "cache_dir=\"$ROOT_PREFIX/var/mobile/Library/Caches/$STATE_PARENT\"",
        "config_dir=\"$ROOT_PREFIX/var/mobile/Library/Preferences/$STATE_PARENT\"",
        "seed_root_dir=\"$support_dir/$SEED_ROOT_DIR\"",
        "root_seed_file=\"$seed_root_dir/$ROOT_SEED_FILE\"",
        "policy_file=\"$config_dir/$POLICY_FILE\"",
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
        "    if [ ! -f \"$policy_file\" ]; then",
        "      umask 022",
        "      tmp=\"$config_dir/.$POLICY_FILE.$$\"",
        "      printf 'D|0|0|0|\\n' > \"$tmp\"",
        "      chmod 644 \"$tmp\"",
        "      mv \"$tmp\" \"$policy_file\"",
        "    fi",
        "    if command -v chown >/dev/null 2>&1; then",
        "      chown mobile:mobile \"$support_dir\" \"$cache_dir\" \"$config_dir\" \"$seed_root_dir\" \"$root_seed_file\" \"$policy_file\" 2>/dev/null || true",
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
    write_executable(layout_dir / "usr/bin/lhctl", toggle_helper_script(package_state_parent, package_policy_file, selected))


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
    package_policy_file = package_policy_file_name(instance_seed)
    mitigations = normalize_catalog(catalog)
    for index, item in enumerate(mitigations.values(), start=1):
        item["moduleID"] = index
    policy_values = normalize_policy_values(value_catalog)
    selected, selected_values = validate_selection(selection, mitigations, policy_values)
    label_sources = selected_source_paths(selected, selected_values) + core_derivation_label_source_paths()
    derivation_labels = discover_derivation_labels(list(dict.fromkeys(label_sources)), instance_seed)
    emit_make_fragment(selected, selected_values)
    emit_registry(mitigations.values(), selected)
    emit_generated_config(instance_seed, package_state_parent, package_seed_root_directory, package_root_seed_file, package_policy_file)
    emit_derivation_labels(derivation_labels)
    emit_policy_value_registry(selected_values)
    emit_package_layout(package_state_parent, package_seed_root_directory, package_root_seed_file, package_policy_file, selected)


if __name__ == "__main__":
    main()
