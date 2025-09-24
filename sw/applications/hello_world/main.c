// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

#include <stdio.h>
#include <stdlib.h>
#include "CB_Safety.h"
#include "cvxif_macros.h"
#include "ccsds_csr.h"
#include "sample_000244_u32be_128x1x2_hex.h"
#include "sample_005535_s32be_2x16x4_hex.h"

#define CVXIF 1
#define SIZE_256 0

int main(int argc, char *argv[])
{


#if CVXIF
  #if SIZE_256
    uintptr_t addr = (uintptr_t)&SAMPLE_000244_DATA;

    asm volatile ("mv a1, %0" :: "r"(addr) : "a1");   // a1 = addr
    asm volatile("li a2, 0xF002E000");
    asm volatile("li a0, 256");
    asm volatile("accsds_load a0"); //Send RAW Size data + Reset de accelerator
    asm volatile("accsds_start a0, a1, a2"); //Overwrite Compress Size

  #else
    uintptr_t addr = (uintptr_t)&SAMPLE_005535_DATA;

    asm volatile ("mv a1, %0" :: "r"(addr) : "a1");   // a1 = addr
    asm volatile("li a2, 0xF002E000");
    asm volatile("li a0, 128");
    asm volatile("accsds_load a0"); //Send RAW Size data + Reset de accelerator
    asm volatile("accsds_start a0, a1, a2"); //Overwrite Compress Size
  #endif
#else

  volatile unsigned int *CCSDS_CSR_WRITE_BASEADDR_REG = 0xF0011000 + CCSDS_CSR_WRITE_BASEADDR_REG_OFFSET;
  volatile unsigned int *CCSDS_CSR_READ_BASEADDR_REG = 0xF0011000 + CCSDS_CSR_READ_BASEADDR_REG_OFFSET;
  volatile unsigned int *CCSDS_CSR_RAWSIZE_REG = 0xF0011000 + CCSDS_CSR_RAWSIZE_REG_OFFSET;
  volatile unsigned int *CCSDS_CSR_START_REG = 0xF0011000 + CCSDS_CSR_START_REG_OFFSET;
  volatile unsigned int *CCSDS_CSR_COMPRESSEDSIZE_REG = 0xF0011000 + CCSDS_CSR_COMPRESSEDSIZE_REG_OFFSET;
  volatile unsigned int *CCSDS_CSR_DONE_REG = 0xF0011000 + CCSDS_CSR_DONE_REG_OFFSET;

  *CCSDS_CSR_START_REG = 0x0; //clear
  *CCSDS_CSR_WRITE_BASEADDR_REG = 0xF002E000;
  *CCSDS_CSR_READ_BASEADDR_REG = &SAMPLE_005535_DATA;
  *CCSDS_CSR_RAWSIZE_REG = 128;
  *CCSDS_CSR_START_REG = 0x1;
  while((*CCSDS_CSR_DONE_REG) == 0);
  *CCSDS_CSR_START_REG = 0x0; //clear
  *CCSDS_CSR_WRITE_BASEADDR_REG = 0xF002E000;
  *CCSDS_CSR_READ_BASEADDR_REG = &SAMPLE_000244_DATA;
  *CCSDS_CSR_RAWSIZE_REG = 256;
  *CCSDS_CSR_START_REG = 0x1;
  while((*CCSDS_CSR_DONE_REG) == 0);
  printf("Read Addr %u",&SAMPLE_000244_DATA);
  printf("CCSDS Data compression size %u\n",*CCSDS_CSR_COMPRESSEDSIZE_REG);

#endif

  printf("[EROS]: Hello world!\n");

  return 0;
}