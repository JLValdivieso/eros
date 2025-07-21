// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

#ifndef _BASE_ADDRESS_DEFS_
#define _BASE_ADDRESS_DEFS_

#ifdef __cplusplus
extern "C" {
#endif

#ifdef __cplusplus
}  // extern "C"
#endif

//Define
#define GLOBAL_BASE_ADDRESS ${SystemBus.BaseAddress}	/*User defined*/
#define SAFE_CSR_BASE_ADDRESS ${CSR.BaseAddress} /*User defined*/


//Priv Reg
#define PRIVATE_REG_BASEADDRESS 0x00000000 | GLOBAL_BASE_ADDRESS

//Priv Reg
#define SAFE_WRAPPER_CTRL_BASEADDRESS    (SAFE_CSR_BASE_ADDRESS)

//Debug BOOT ADDRESS
#define BOOT_DEBUG_ROM_BASEADDRESS (0x00010000 | GLOBAL_BASE_ADDRESS)

#define BOOT_OFFSET     (BOOT_DEBUG_ROM_BASEADDRESS | 0x0)
#define DEBUG_OFFSET    (BOOT_DEBUG_ROM_BASEADDRESS | 0x50)

#endif