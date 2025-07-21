#!/usr/bin/env python3
"""
Script to generate:
  - rtl/include/eros_pkg.sv from configs/addr.hjson and eros_pkg.sv.tpl
  - sw/linker/link.ld from configs/addr.hjson and link.ld.tpl
  - sw/CB_device/lib/base_address/base_address.h from configs/addr.hjson and base_address.h.tpl
by replacing placeholders `${section.subsection}` with hex values
(SV templates assume `32'h` prefix in file; all others receive `0x` prefix).

Usage:
    $ python generate_files.py

Assumes:
  - config file at: configs/addr.hjson
  - templates at:
      - rtl/include/eros_pkg.sv.tpl
      - sw/linker/link.ld.tpl
      - sw/CB_device/lib/base_address/base_address.h.tpl
  - outputs alongside templates, removing `.tpl` suffix.

Dependencies:
  pip install hjson
"""
import hjson
import re
from pathlib import Path
import sys


def get_config_value(cfg, path):
    val = cfg
    for key in path:
        if isinstance(val, dict) and key in val:
            val = val[key]
        else:
            raise KeyError(f"Config key '{'.'.join(path)}' not found")
    return val


def to_hex_string(val):
    if isinstance(val, int):
        s = format(val, 'X')
    else:
        s = str(val).strip().strip('"').strip("'")
        if s.lower().startswith('0x'):
            s = s[2:]
    return s.upper()


def process_template(template_path: Path, cfg: dict):
    content = template_path.read_text()
    # Choose prefix: no 0x for SV templates (SV file includes 32'h), 0x for others
    is_sv = template_path.name.endswith('.sv.tpl')
    prefix = '' if is_sv else '0x'

    pattern = re.compile(r"\$\{([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*)\}")

    def repl(match):
        keypath = match.group(1).split('.')
        try:
            val = get_config_value(cfg, keypath)
        except KeyError as e:
            print(f"Warning: {e}", file=sys.stderr)
            return match.group(0)
        hexstr = to_hex_string(val)
        return f"{prefix}{hexstr}"

    new_content, count = pattern.subn(repl, content)
    print(f"[{template_path.name}] Replacements: {count}")
    return new_content


def main():
    config_path = Path('configs/addr.hjson')
    if not config_path.is_file():
        print(f"Error: config file not found at {config_path}", file=sys.stderr)
        sys.exit(1)

    raw = config_path.read_text()
    # strip comments (# ...)
    clean = re.sub(r"#.*", "", raw)
    try:
        cfg = hjson.loads(clean)
    except Exception as e:
        print(f"Error parsing HJSON: {e}", file=sys.stderr)
        sys.exit(1)

    templates = [
        Path('rtl/include/eros_pkg.sv.tpl'),
        Path('sw/linker/link.ld.tpl'),
        Path('sw/CB_device/lib/base_address/base_address.h.tpl'),
    ]

    for tpl_path in templates:
        if not tpl_path.is_file():
            print(f"Error: template not found at {tpl_path}", file=sys.stderr)
            continue
        out_path = tpl_path.with_suffix('')
        result = process_template(tpl_path, cfg)
        out_path.write_text(result)
        print(f"Generated {out_path}")

if __name__ == '__main__':
    main()
