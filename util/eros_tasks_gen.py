#!/usr/bin/env python3

# Copyright 2026 CEI UPM
# SPDX-License-Identifier: Apache-2.0
# Jonathan Valdivieso (jonathan.lvaldivieso@upm.es)
#
# Generates the memory layout for N independent EROS tasks that live in memory
# at the same time:
#
#   sw/linker/link_task<i>.ld                     one linker script per task
#   sw/CB_device/lib/base_address/eros_tasks.h    layout for the EROS side
#   sw/host/eros_tasks.h                          same header for the host
#

import argparse
import hjson
import sys
from pathlib import Path

# RAM banks, must match MEMORY_RAM*_START_ADDRESS / SIZE in rtl/include/eros_pkg.sv.tpl
RAM0_OFFSET = 0x00020000
RAM0_SIZE = 0x00010000
RAM1_OFFSET = 0x00030000
RAM1_SIZE = 0x00010000

BOOT_OFFSET = 0x180      # crt0 entry inside a code slot (after the vector table)
CODE_ALIGN = 0x100       # mtvec in vectored mode needs 256 B alignment
DATA_ALIGN = 0x10        # stack alignment required by the ABI
STACK_ALIGN = 0x100      # granularity of the auto-sized stack
STACK_GUARD = 0x10       # gap between the initial sp and the end of a data slot
STACK_SHARE = 4          # stack = 1/STACK_SHARE of the RAM1 share of a task

FRAME_SIZE = 148         # CB_Safety.c context frame: 5 CSRs + x1..x31 + PC
SIGNATURE_WORDS = 8      # 32-bit signatures checked by the host

DEFAULTS = {
    "NTasks": 2,
    "StackSize": 0x800,  # minimum, the generator may give more
    "HeapSize": 0x400,
    # Smallest slots accepted, used to compute the maximum number of tasks.
    # A task built with the safety library takes ~6 KiB of code and ~0.7 KiB
    # of .rodata/.data/.bss besides heap and stack.
    "MinCodeSize": 0x2000,
    "MinStaticDataSize": 0x400,
}


def align_up(x, a):
    return (x + a - 1) // a * a


def align_down(x, a):
    return x // a * a


def to_int(val):
    return val if isinstance(val, int) else int(str(val).strip().strip('"'), 0)


def load_config(path):
    cfg = hjson.loads(Path(path).read_text())
    base = to_int(cfg["BaseAddressConfiguration"]["SystemBus"]["BaseAddress"])
    tasks = dict(DEFAULTS)
    for key, val in cfg.get("TaskConfiguration", {}).items():
        tasks[key] = to_int(val)
    return base, tasks


def system_size(n):
    return align_up(4 * SIGNATURE_WORDS, DATA_ALIGN)


def preempt_size():
    return align_up(FRAME_SIZE, DATA_ALIGN)


def safe_copy_size(stack):
    return align_up(FRAME_SIZE + stack + 4, DATA_ALIGN)


def data_min(t, stack):
    return align_up(t["MinStaticDataSize"] + t["HeapSize"] + stack + STACK_GUARD, DATA_ALIGN)


def task_share(n):
    # RAM1 bytes available to each task (its data slot plus its ctx block)
    return align_down((RAM1_SIZE - system_size(n)) // n, DATA_ALIGN)


def fits(t, n):
    s = t["StackSize"]
    return (RAM0_SIZE // n >= t["MinCodeSize"]
            and preempt_size() + safe_copy_size(s) + data_min(t, s) <= task_share(n))


def max_tasks(t):
    n = 0
    while fits(t, n + 1):
        n += 1
    return n


def compute_layout(base, t):
    n = t["NTasks"]
    share = task_share(n)
    stack = max(t["StackSize"], align_down(share // STACK_SHARE, STACK_ALIGN))
    preempt = preempt_size()
    safe_copy = safe_copy_size(stack)
    ctx_size = preempt + safe_copy

    ram0 = base + RAM0_OFFSET
    ram1 = base + RAM1_OFFSET
    system = ram1 + RAM1_SIZE - system_size(n)
    signature = ram1 + RAM1_SIZE - 4 * SIGNATURE_WORDS
    ctx_base = system - n * ctx_size

    code_size = align_down(RAM0_SIZE // n, CODE_ALIGN)
    data_size = align_down((ctx_base - ram1) // n, DATA_ALIGN)

    tasks = []
    for i in range(n):
        code = ram0 + i * code_size
        data = ram1 + i * data_size
        ctx = ctx_base + i * ctx_size
        tasks.append({
            "code": code,
            "code_size": code_size,
            "entry": code + BOOT_OFFSET,
            "data": data,
            "data_size": data_size,
            "initial_sp": data + data_size - STACK_GUARD,
            "preempt_ctx": ctx,
            "safe_copy": ctx + preempt,
        })

    return {
        "n": n,
        "stack": stack,
        "heap": t["HeapSize"],
        "preempt_size": preempt,
        "safe_copy_size": safe_copy,
        "signature": signature,
        "free": ctx_base - (ram1 + n * data_size),
        "tasks": tasks,
    }


def layout_table(lay, prefix):
    lines = [f"{prefix}stack {lay['stack']} B, heap {lay['heap']} B, "
             f"safe copy {lay['safe_copy_size']} B, preempt ctx {lay['preempt_size']} B per task"]
    for i, tk in enumerate(lay["tasks"]):
        lines.append(f"{prefix}task{i}  code 0x{tk['code']:08X} ({tk['code_size'] / 1024:g} KiB)  "
                     f"entry 0x{tk['entry']:08X}  data 0x{tk['data']:08X} "
                     f"({tk['data_size'] / 1024:.2f} KiB)  sp 0x{tk['initial_sp']:08X}")
        lines.append(f"{prefix}       preempt ctx 0x{tk['preempt_ctx']:08X}  "
                     f"safe copy 0x{tk['safe_copy']:08X}")
    lines.append(f"{prefix}signature 0x{lay['signature']:08X} ({SIGNATURE_WORDS} words)  "
                 f"unused {lay['free']} B")
    return "\n".join(lines)


def gen_linker(lay, i):
    tk = lay["tasks"][i]
    # The data region stops at the initial sp so the stack (placed at the top
    # of the region by link_task_common.ld) leaves the guard bytes free.
    data_len = tk["initial_sp"] - tk["data"]
    return f"""/* Linker script for TASK {i} of {lay['n']}.
   Generated by util/eros_tasks_gen.py, do not edit: change the
   TaskConfiguration of the EROS config (or NTASKS) and regenerate.

{layout_table(lay, '     ')}
*/

MEMORY
{{
  code (rwxai) : ORIGIN = 0x{tk['code']:08X}, LENGTH = 0x{tk['code_size']:08X}
  data (rwxai) : ORIGIN = 0x{tk['data']:08X}, LENGTH = 0x{data_len:08X}
}}

__task_boot_offset = 0x{BOOT_OFFSET:X};
__stack_size = 0x{lay['stack']:X};
__heap_size = 0x{lay['heap']:X};

PROVIDE(__task_id = {i});
PROVIDE(__preempt_ctx_start = 0x{tk['preempt_ctx']:08X});
PROVIDE(__safe_copy_start = 0x{tk['safe_copy']:08X});

INCLUDE link_task_common.ld

ASSERT(_sp == 0x{tk['initial_sp']:08X}, "task stack top does not match EROS_TASK{i}_INITIAL_SP")
ASSERT(__stack_size <= 0x{lay['stack']:X}, "stack larger than the SAFE_COPY slot of this task")
"""


def gen_header(lay):
    defines = [
        f"#define EROS_NTASKS                 {lay['n']}",
        "",
        f"#define EROS_TASK_STACK_SIZE        0x{lay['stack']:X}",
        f"#define EROS_PREEMPT_CTX_SIZE       0x{lay['preempt_size']:X}",
        f"#define EROS_SAFE_COPY_SIZE         0x{lay['safe_copy_size']:X}",
        "",
        f"#define EROS_SIGNATURE_ADDRESS      0x{lay['signature']:08X}",
        f"#define EROS_SIGNATURE_WORDS        {SIGNATURE_WORDS}",
    ]
    for i, tk in enumerate(lay["tasks"]):
        defines.append("")
        for name, key in (("CODE_ADDRESS", "code"), ("CODE_SIZE", "code_size"),
                          ("ENTRY_ADDRESS", "entry"), ("DATA_ADDRESS", "data"),
                          ("DATA_SIZE", "data_size"), ("INITIAL_SP", "initial_sp"),
                          ("PREEMPT_CTX", "preempt_ctx"), ("SAFE_COPY", "safe_copy")):
            defines.append(f"#define EROS_TASK{i}_{name:<15} 0x{tk[key]:08X}")

    table = " \\\n".join(
        f"    {{ EROS_TASK{i}_ENTRY_ADDRESS, EROS_TASK{i}_PREEMPT_CTX, "
        f"EROS_TASK{i}_SAFE_COPY, EROS_TASK{i}_INITIAL_SP }},"
        for i in range(lay["n"]))

    return f"""// Generated by util/eros_tasks_gen.py, do not edit.
//
// Memory layout of the {lay['n']} EROS task(s). The same file is written to
// sw/CB_device/lib/preemptive/ (EROS side) and sw/host/ (host side): both
// sides must be built against the same layout.
//
{layout_table(lay, '//   ')}

#ifndef _EROS_TASKS_H_
#define _EROS_TASKS_H_

{chr(10).join(defines)}

// Initializer for an array of eros_task_t, indexed by task id
typedef struct {{
    unsigned int entry;        // ENTRY_ADDRESS
    unsigned int preempt_ctx;  // PREEMPTIVE_CONTEXT_ADDRESS
    unsigned int safe_copy;    // SAFE_COPY_ADDRESS
    unsigned int initial_sp;   // INITIAL_STACK_ADDR, to restore on resume
}} eros_task_t;

#define EROS_TASK_TABLE {{ \\
{table} \\
}}

#endif
"""


def main():
    parser = argparse.ArgumentParser(description="Generate the EROS multi-task memory layout")
    parser.add_argument("--addr_config", required=True, help="Path to HJSON configuration file")
    parser.add_argument("--ntasks", type=int, help="Number of tasks (overrides TaskConfiguration.NTasks)")
    args = parser.parse_args()

    base, t = load_config(args.addr_config)
    if args.ntasks is not None:
        t["NTasks"] = args.ntasks

    n_max = max_tasks(t)
    print(f"[eros_tasks_gen] max tasks: {n_max}")

    if not 1 <= t["NTasks"] <= n_max:
        print(f"Error: NTasks = {t['NTasks']}, must be between 1 and {n_max} with "
              f"StackSize 0x{t['StackSize']:X}, HeapSize 0x{t['HeapSize']:X}", file=sys.stderr)
        sys.exit(1)

    lay = compute_layout(base, t)
    print(layout_table(lay, "  "))

    linker_dir = Path("sw/linker")
    for old in linker_dir.glob("link_task[0-9]*.ld"):
        old.unlink()
    for i in range(lay["n"]):
        out = linker_dir / f"link_task{i}.ld"
        out.write_text(gen_linker(lay, i))
        print(f"Generated {out}")

    header = gen_header(lay)
    for out in (Path("sw/CB_device/lib/preemptive/eros_tasks_addr.h"), Path("sw/host/eros_tasks_addr.h")):
        out.write_text(header)
        print(f"Generated {out}")


if __name__ == "__main__":
    main()
