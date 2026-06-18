#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import re
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


def write_file(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


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


def emit_generated_config(instance_seed):
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
        "",
    ])

    write_file(ROOT / "core/generated/LHGeneratedConfig.h", header)
    write_file(ROOT / "core/generated/LHGeneratedConfig.c", source)


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
    mitigations = normalize_catalog(catalog)
    policy_values = normalize_policy_values(value_catalog)
    selected, selected_values = validate_selection(selection, mitigations, policy_values)
    derivation_labels = discover_derivation_labels(selected_source_paths(selected, selected_values), instance_seed)
    emit_make_fragment(selected, selected_values)
    emit_registry(mitigations.values(), selected)
    emit_generated_config(instance_seed)
    emit_derivation_labels(derivation_labels)
    emit_policy_value_registry(selected_values)


if __name__ == "__main__":
    main()
