// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include "CB_Safety.h"

#define SIGNATURE ((volatile uint32_t *)0x03063F00)

int main(int argc, char *argv[])
{
    int a, b, c;

    a = 5;
    b = 10;
    c = a + b;

    /*
     * Memory signature for Cheshire verification
     */
    SIGNATURE[0] = 0xDEADBEEF;  // main reached
    SIGNATURE[1] = a;           // 5
    SIGNATURE[2] = b;           // 10
    SIGNATURE[3] = c;           // 15
    SIGNATURE[4] = 0xCAFEBABE;  // computation completed

    while (1) {
        asm volatile("nop");
    }

    return 0;
}