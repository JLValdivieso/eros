#!/usr/bin/env python3

# Copyright 2026 CEI UPM
# SPDX-License-Identifier: Apache-2.0
# Jonathan Valdivieso (jonathan.lvaldivieso@upm.es)
#
# Merges the ELF images of the EROS tasks (sw/build_tasks/task<i>/main.elf)
# into one raw binary covering RAM0 + RAM1, to be loaded once at its base
# address. Loading the per-task main<i>.bin one after the other does not
# work: each of them is padded with zeros between its code and its data
# window, and that padding overwrites the other tasks.

import argparse
import struct
import sys
from pathlib import Path

PT_LOAD = 1


def load_segments(path):
    data = Path(path).read_bytes()
    if data[:4] != b"\x7fELF" or data[4] != 1 or data[5] != 1:
        sys.exit(f"Error: {path} is not a 32-bit little-endian ELF")

    e_phoff, = struct.unpack_from("<I", data, 0x1C)
    e_phentsize, e_phnum = struct.unpack_from("<HH", data, 0x2A)

    for n in range(e_phnum):
        p_type, p_offset, _vaddr, p_paddr, p_filesz, _memsz, _flags, _align = \
            struct.unpack_from("<8I", data, e_phoff + n * e_phentsize)
        if p_type == PT_LOAD and p_filesz:
            yield p_paddr, data[p_offset:p_offset + p_filesz]


def main():
    parser = argparse.ArgumentParser(description="Merge EROS task ELFs into one binary")
    parser.add_argument("--base", type=lambda x: int(x, 0), default=0x03060000,
                        help="load address of the image (RAM0 start)")
    parser.add_argument("--size", type=lambda x: int(x, 0), default=0x20000,
                        help="image size (RAM0 + RAM1)")
    parser.add_argument("-o", "--output", required=True)
    parser.add_argument("elfs", nargs="+")
    args = parser.parse_args()

    image = bytearray(args.size)
    owner = [None] * args.size

    for elf in args.elfs:
        for addr, chunk in load_segments(elf):
            off = addr - args.base
            if off < 0 or off + len(chunk) > args.size:
                sys.exit(f"Error: {elf} segment 0x{addr:08X} is outside the image")
            for k in range(off, off + len(chunk)):
                if owner[k] is not None:
                    sys.exit(f"Error: {elf} overlaps {owner[k]} at 0x{args.base + k:08X}")
                owner[k] = elf
            image[off:off + len(chunk)] = chunk
            print(f"  0x{addr:08X} - 0x{addr + len(chunk) - 1:08X}  {elf}")

    Path(args.output).write_bytes(image)
    print(f"Generated {args.output}: load at 0x{args.base:08X}, {args.size} bytes")


if __name__ == "__main__":
    main()
