// Copyright 2022 Thales DIS design services SAS
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0
// You may obtain a copy of the License at https://solderpad.org/licenses/
//
// Original Author: Zineb EL KACIMI (zineb.el-kacimi@external.thalesgroup.com)
// Contributor : Guillaume Chauvon

// Add user macros, routines in this file

// Mappings of custom_* mnemonics to .insn pseudo-op of GAS

// CUS_ADD rd, rs1, rs2 -> .insn r CUSTOM_3, 0x1, 0x0, rd, rs1, rs2
//__asm__ (".macro  cus_add rd, rs1, rs2");
//    __asm__ (".insn r CUSTOM_3, 0x1, 0x0, \\rd, \\rs1, \\rs2");
// __asm__ (".endm");

// CUS_NOP -> .insn r CUSTOM_3, 0x0, 0x0, x0, x0, x0
//__asm__ (".macro  cus_nop");
//    __asm__ (".insn r CUSTOM_3, 0x0, 0x0, x0, x0, x0");
//__asm__(".endm");

// CUS_NOP -> .insn r CUSTOM_3, 0x0, 0x0, x0, x0, x0
__asm__ (".macro  accsds_load, rs1");
    __asm__ (".insn r CUSTOM_3, 0x0, 0x0, x0, \\rs1, x0");
__asm__(".endm");

// CUS_NOP -> .insn r CUSTOM_3, 0x0, 0x0, x0, x0, x0
__asm__ (".macro  accsds_start rd, rs1, rs2");
    __asm__ (".insn r CUSTOM_3, 0x1, 0x0, \\rd, \\rs1, \\rs2");
__asm__(".endm");