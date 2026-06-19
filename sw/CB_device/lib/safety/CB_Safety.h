// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

#ifndef _CB_SAFETY_H_
#define _CB_SAFETY_H_

//Todo: Check if __cplusplus this is necesary
#ifdef __cplusplus
extern "C" {
#endif

#ifdef __cplusplus
}
#endif

#include "base_address.h"
#include "CPU_Private_regs.h"
#include "CB_heep_ctrl_regs.h"
#include "Safe_wrapper_ctrl_regs.h"
#include "CB_Safety_Config.h"

#define CHECK_RAM_ADDRESS       0xF002B000

#define FREE_LOCATION_POINTER   0xF002A000

//Functions
#define INTERRUPT_HANDLER_ABI __attribute__((aligned(4), interrupt))

__attribute__((aligned(4))) void Safe_Activate(unsigned int mode);
__attribute__((aligned(4))) void Safe_Stop(unsigned int master);
__attribute__((aligned(4),always_inline)) inline void Set_Critical_Section(unsigned int critical){
        volatile unsigned int *Priv_Reg = (volatile unsigned int *)(SAFE_WRAPPER_CTRL_BASEADDRESS +
                              SAFE_WRAPPER_CTRL_CRITICAL_SECTION_REG_OFFSET);
        }
        
__attribute__((aligned(4))) void Store_Checkpoint(void);
__attribute__((aligned(4))) void Check_RF(void);

//Handlers
INTERRUPT_HANDLER_ABI void handler_tmr_recoverysync(void);
INTERRUPT_HANDLER_ABI void handler_tmr_dmcontext_copy(void);
INTERRUPT_HANDLER_ABI void handler_tmr_dmshsync(void);
INTERRUPT_HANDLER_ABI void handler_safe_fsm(void);


#endif  
