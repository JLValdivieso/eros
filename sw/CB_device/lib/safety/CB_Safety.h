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
#include "eros_tasks_addr.h"

// #define FREE_LOCATION_POINTER   0xF002A000

// Preemption timing: handler_preemptive_store_context resets mcycle at its
// entry and writes it at the end of the save (cycles spent in the handler)
// into the free bytes after the 148 B frame of the PREEMPTIVE_CONTEXT slot
// (the slot must be at least 156 B, it is 160 B in the layout of
// util/eros_tasks_gen.py). Set it to 0 for a 148 B slot.
#ifndef PREEMPT_TIMING
#define PREEMPT_TIMING 1
#endif
#define PREEMPT_TIMING_END_OFFSET   152

//Functions
#define INTERRUPT_HANDLER_ABI __attribute__((aligned(4), interrupt))

__attribute__((aligned(4))) void Safe_Activate(unsigned int mode);
__attribute__((aligned(4))) void Safe_Stop(unsigned int master);
__attribute__((aligned(4),always_inline)) inline void Set_Critical_Section(unsigned int critical){
        volatile unsigned int *Priv_Reg = (volatile unsigned int *)(SAFE_WRAPPER_CTRL_BASEADDRESS +
                              SAFE_WRAPPER_CTRL_CRITICAL_SECTION_REG_OFFSET);
        *Priv_Reg = critical;}

__attribute__((aligned(4))) void Store_Checkpoint(void);

//Handlers
INTERRUPT_HANDLER_ABI void handler_tmr_recoverysync(void);
INTERRUPT_HANDLER_ABI void handler_host_safe_activate(void);
INTERRUPT_HANDLER_ABI void handler_host_safe_stop(void);
INTERRUPT_HANDLER_ABI void handler_safe_fsm(void);
INTERRUPT_HANDLER_ABI void handler_preemptive_store_context(void);


#endif
