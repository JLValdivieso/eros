// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

#include <stdio.h>
#include <stdlib.h>
#include "CB_Safety.h"
#include "cvxif_macros.h"



int main(int argc, char *argv[])
{
asm volatile("li a1, 0xF002A000");
asm volatile("li a2, 0xF002E000");
asm volatile("li a0, 0x1000");
asm volatile("accsds_load a0"); //Send RAW Size data
asm volatile("accsds_start a0, a1, a2"); //Overwrite Compress Size

printf("[EROS]: Hello world!\n");

    return 0;
}