/* Copyright (c) 2017  SiFive Inc. All rights reserved.
 * Copyright (c) 2019  ETH Zürich and University of Bologna
 * Copyright (c) 2022 EPFL
 * This copyrighted material is made available to anyone wishing to use,
 * modify, copy, or redistribute it subject to the terms and conditions
 * of the FreeBSD License.   This program is distributed in the hope that
 * it will be useful, but WITHOUT ANY WARRANTY expressed or implied,
 * including the implied warranties of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE.  A copy of this license is available at
 * http://www.opensource.org/licenses.
 */

//#include "x-heep.h"
//#include "core_v_mini_mcu.h"
//#include "soc_ctrl_regs.h"

#include "base_address.h"
#include "CPU_Private_regs.h"
#include "Safe_wrapper_ctrl_regs.h"

#define RAMSIZE_COPIEDBY_BOOTROM 2048

/* Entry point for bare metal programs */
.section .text.start
.global _start
.type _start, @function

_start:
/* initialize global pointer */
.option push
.option norelax
1: auipc gp, %pcrel_hi(__global_pointer$)
   addi  gp, gp, %pcrel_lo(1b)
.option pop

/* initialize stack pointer */
   la sp, _sp


/* clear the bss segment */
_init_bss:
    la     a0, __bss_start
    la     a2, __bss_end
    sub    a2, a2, a0
    li     a1, 0
    call   memset

#ifdef FLASH_EXEC
/* copy initialized data sections from flash to ram (to be verified, copied from picosoc)*/
    la a0, _sidata
    la a1, _sdata
    la a2, _edata
    bge a1, a2, end_init_data
    loop_init_data:
    lw a3, 0(a0)
    sw a3, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    blt a1, a2, loop_init_data
    end_init_data:
#endif

/* set vector table address and vectored mode */
    la a0, __vector_start
    ori a0, a0, 0x1
    csrw mtvec, a0

/* set active interruption */
    csrr a0, mstatus;
    ori a0,a0,0x08; 
    csrw mstatus, a0;  
   /*Set mie.MEIE bit mask to one to enable machine-level external interrupts*/
    li   a0,0xFFFF0000 
    csrw mie, a0      

/* new-style constructors and destructors */
/*
    la a0, __libc_fini_array
    call atexit
    call __libc_init_array
*/
/* call main */
    li a0, SAFE_WRAPPER_CTRL_BASEADDRESS | SAFE_WRAPPER_CTRL_INITIAL_STACK_ADDR_REG_OFFSET
    sw sp, 0(a0)
    lw a0, 0(sp)                    /* a0 = argc */
    addi a1, sp, __SIZEOF_POINTER__ /* a1 = argv */
    li a2, 0                        /* a2 = envp = NULL */
    call main
    tail _exit

.size  _start, .-_start

.global _init
.type   _init, @function
.global _fini
.type   _fini, @function
_init:
    call init
_fini:
 /* These don't have to do anything since we use init_array/fini_array. Prevent
    missing symbol error */
    ret
.size  _init, .-_init
.size _fini, .-_fini



