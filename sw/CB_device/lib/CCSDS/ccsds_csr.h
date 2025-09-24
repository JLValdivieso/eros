// Generated register defines for CCSDS_CSR

// Copyright information found in source file:
// Copyright lowRISC contributors.

// Licensing information found in source file:
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef _CCSDS_CSR_REG_DEFS_
#define _CCSDS_CSR_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define CCSDS_CSR_PARAM_REG_WIDTH 32

// Start/Stop de accelerator
#define CCSDS_CSR_START_REG_OFFSET 0x0
#define CCSDS_CSR_START_START_BIT 0

// Write BaseAddress to store compressed data
#define CCSDS_CSR_WRITE_BASEADDR_REG_OFFSET 0x4

// Write BaseAddress to store compressed data
#define CCSDS_CSR_READ_BASEADDR_REG_OFFSET 0x8

// Raw size in words/size
#define CCSDS_CSR_RAWSIZE_REG_OFFSET 0xc

// Size of n words compressed packets
#define CCSDS_CSR_COMPRESSEDSIZE_REG_OFFSET 0x10

// Accelerator finish the compression
#define CCSDS_CSR_DONE_REG_OFFSET 0x14
#define CCSDS_CSR_DONE_DONE_BIT 0

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _CCSDS_CSR_REG_DEFS_
// End generated register defines for CCSDS_CSR