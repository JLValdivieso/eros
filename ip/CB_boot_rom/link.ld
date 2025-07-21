/*  Copyright 2025 CEI UPM
*   Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
*   SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
*   Luis Waucquez (luis.waucquez.jimenez@upm.es)
*/
ENTRY(entry)

MEMORY {
    rom (rx) : ORIGIN = 0x00000000, LENGTH = 0x2000
}

SECTIONS {
    .text 0x0 : {
        *(.text)
        . = ALIGN(4);
        FILL(0x00000013) /*NOP*/
        . += 0x50 - .;
        *(.debug_entry)
        . = ALIGN(4);
        FILL(0x00000013) /*NOP*/
        . += 0x200 - .;
        *(.shadow_wfi)
    } > rom
}