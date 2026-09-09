#!/usr/bin/env python3

import argparse
import hjson
import re
import sys
from pathlib import Path


DECIMAL_FIELDS = {
    "CPUConfiguration.NCycles",
    "AcceleratorAndCoprocessor.NMasterCoprocessor",
    "AcceleratorAndCoprocessor.NMasterAccelerator",
}

IDENTIFIER_FIELDS = {
    "CPUConfiguration.CPU",
    "AcceleratorAndCoprocessor.CoprocessorName",
    "AcceleratorAndCoprocessor.AcceleratorName",
}


def find_key_recursive(obj, wanted_key):
    if isinstance(obj, dict):
        if wanted_key in obj:
            return obj[wanted_key]

        for value in obj.values():
            found = find_key_recursive(value, wanted_key)
            if found is not None:
                return found

    elif isinstance(obj, list):
        for value in obj:
            found = find_key_recursive(value, wanted_key)
            if found is not None:
                return found

    return None


def get_config_value(cfg, path):
    val = cfg

    for key in path:
        if isinstance(val, dict) and key in val:
            val = val[key]
        else:
            # Backward-compatible fallback for old flat config keys
            if len(path) == 1:
                found = find_key_recursive(cfg, path[0])
                if found is not None:
                    return found

            raise KeyError(f"Config key '{'.'.join(path)}' not found")

    return val


def value_as_string(val):
    return str(val).strip().strip('"').strip("'")


def to_hex_string(val):
    if isinstance(val, int):
        s = format(val, "X")
    else:
        s = value_as_string(val)
        if s.lower().startswith("0x"):
            s = s[2:]

    return s.upper()


def to_decimal_string(val):
    if isinstance(val, int):
        return str(val)

    return str(int(value_as_string(val), 0))


def to_identifier_string(val):
    return value_as_string(val)


def to_yes_no_number(val):
    if isinstance(val, bool):
        return "1" if val else "0"

    if isinstance(val, str):
        s = value_as_string(val).lower()

        if s == "yes":
            return "1"

        if s == "no":
            return "0"

    return None


def format_config_value(keypath, val, is_sv):
    key = ".".join(keypath)

    yes_no = to_yes_no_number(val)
    if yes_no is not None:
        return yes_no

    if key in DECIMAL_FIELDS:
        return to_decimal_string(val)

    if key in IDENTIFIER_FIELDS:
        return to_identifier_string(val)

    prefix = "" if is_sv else "0x"
    return f"{prefix}{to_hex_string(val)}"


def eval_single_condition(expr, cfg):
    expr = expr.strip()

    if "==" in expr:
        left, right = expr.split("==", 1)
        left = left.strip()
        right = value_as_string(right)

        left_val = get_config_value(cfg, left.split("."))
        return value_as_string(left_val) == right

    if "!=" in expr:
        left, right = expr.split("!=", 1)
        left = left.strip()
        right = value_as_string(right)

        left_val = get_config_value(cfg, left.split("."))
        return value_as_string(left_val) != right

    val = get_config_value(cfg, expr.split("."))
    return value_as_string(val) != ""


def eval_condition(expr, cfg):
    or_parts = expr.split("||")

    for or_part in or_parts:
        and_parts = or_part.split("&&")

        if all(eval_single_condition(part, cfg) for part in and_parts):
            return True

    return False


def process_if_blocks(content, cfg):
    pattern = re.compile(
        r"\$\{IF\s+(.+?)\}(.*?)\$\{ENDIF\}",
        re.DOTALL,
    )

    while True:
        match = pattern.search(content)
        if not match:
            break

        full_block = match.group(0)
        first_cond = match.group(1).strip()
        body = match.group(2)

        parts = re.split(r"\$\{(ELSEIF\s+.+?|ELSE)\}", body)

        conditions = [first_cond]
        blocks = [parts[0]]

        i = 1
        while i < len(parts):
            token = parts[i].strip()
            block = parts[i + 1]

            if token.startswith("ELSEIF"):
                conditions.append(token[len("ELSEIF"):].strip())
                blocks.append(block)

            elif token == "ELSE":
                conditions.append(None)
                blocks.append(block)

            i += 2

        replacement = ""

        for cond, block in zip(conditions, blocks):
            if cond is None:
                replacement = block
                break

            try:
                if eval_condition(cond, cfg):
                    replacement = block
                    break
            except KeyError as e:
                print(f"Warning: {e}", file=sys.stderr)

        content = content.replace(full_block, replacement, 1)

    return content


def process_template(template_path: Path, cfg: dict):
    content = template_path.read_text()
    content = process_if_blocks(content, cfg)

    is_sv = template_path.name.endswith(".sv.tpl")

    pattern = re.compile(
        r"\$\{([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*)\}"
        r"|\$\(([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*)\)"
    )

    def repl(match):
        placeholder = match.group(1) or match.group(2)
        keypath = placeholder.split(".")

        try:
            val = get_config_value(cfg, keypath)
            return format_config_value(keypath, val, is_sv)

        except (KeyError, ValueError) as e:
            print(f"Warning: {e}", file=sys.stderr)
            return match.group(0)

    new_content, count = pattern.subn(repl, content)

    print(f"[{template_path.name}] Replacements: {count}")

    return new_content


def load_hjson_config(config_path: Path):
    raw = config_path.read_text()
    return hjson.loads(raw)


def main():
    parser = argparse.ArgumentParser(
        description="Generate SV, LD, and H files from HJSON config"
    )

    parser.add_argument(
        "--addr_config",
        required=True,
        help="Path to HJSON configuration file",
    )

    args = parser.parse_args()

    config_path = Path(args.addr_config)

    if not config_path.is_file():
        print(f"Error: config file not found at {config_path}", file=sys.stderr)
        sys.exit(1)

    try:
        cfg = load_hjson_config(config_path)
    except Exception as e:
        print(f"Error parsing HJSON: {e}", file=sys.stderr)
        sys.exit(1)

    templates = [
        Path("rtl/include/eros_pkg.sv.tpl"),
        Path("rtl/cpu_system.sv.tpl"),
        Path("sw/linker/link.ld.tpl"),
        Path("sw/CB_device/lib/base_address/base_address.h.tpl"),
    ]

    for tpl_path in templates:
        if not tpl_path.is_file():
            print(f"Error: template not found at {tpl_path}", file=sys.stderr)
            continue

        out_path = tpl_path.with_suffix("")
        result = process_template(tpl_path, cfg)
        out_path.write_text(result)

        print(f"Generated {out_path}")


if __name__ == "__main__":
    main()