// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

#include <stdio.h>
#include <stdlib.h>
#include "cvxif_macros.h"
#include "csr_registers.h"
#include "CB_Safety.h"


int main(int argc, char *argv[])
{
    volatile uint32_t *P = (volatile uint32_t *)(SAFE_WRAPPER_CTRL_BASEADDRESS + CB_HEEP_CTRL_DMR_MASK_REG_OFFSET);

    uint32_t addr  = GLOBAL_BASE_ADDRESS | 0x28000;
    uint32_t value = *P;
    uint32_t result;

    printf("CV-X-IF\n");

    // Custom-Store
    asm volatile (
        "cvxif_example_store %[val], %[adr]"
        : // Sin salidas
        : [val] "r" (value), [adr] "r" (addr)
        : "memory"
    );

    // Custom-Load
    asm volatile (
        "cvxif_example_load %[res], %[adr]"
        : [res] "=r" (result)
        : [adr] "r" (addr)
        : "memory"
    );

    printf("Result = 0x%08X\n", result);

    return 0;
}