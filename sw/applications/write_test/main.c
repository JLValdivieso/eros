// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

#include <stdio.h>
#include <stdlib.h>
#include "CB_Safety.h"


int main(int argc, char *argv[])
{
  printf("[EROS]: Hello world!\n");
  volatile int i = 0;
  int *P = GLOBAL_BASE_ADDRESS + 0x00020000;
  for (i = 0; i<10000; i++)
    *P = i;

  asm volatile("sw a2, 0(zero)");
  asm volatile("sw a3, 0(zero)");
  asm volatile("sw a2, 0(zero)");
  asm volatile("sw a3, 0(zero)");
  asm volatile("sw a2, 0(zero)");
  asm volatile("sw a3, 0(zero)");
  asm volatile("sw a2, 0(zero)");
  asm volatile("sw a3, 0(zero)");

  return 0;
}