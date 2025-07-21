// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)


 #include "encoding.h"
#define SND_SCRATCH 1
// The debugger can assume as second scratch register.
// These are implementation-specific addresses in the Debug Module
#define HALTED    0x100
#define GOING     0x108
#define RESUMING  0x110
#define EXCEPTION 0x118

#################################
#define GLOBAL_BASE_ADDRESS 0xF0000000
#define SAFE_WRAPPER_CTRL_BASEADDRESS    (0x00012000 | GLOBAL_BASE_ADDRESS)
#define SAFE_WRAPPER_CTRL_SAFE_COPY_ADDRESS_OFFSET      (SAFE_WRAPPER_CTRL_BASEADDRESS | 0x20)

#include "base_address.h"
#include "CPU_Private_regs.h"
#include "Safe_wrapper_ctrl_regs.h"


#################################
// Region of memory where each hart has 1
// byte to read.
#define FLAGS 0x400
#define FLAG_GO     0
#define FLAG_RESUME 1

#include "encoding.h"
#define SND_SCRATCH 1

       .option norvc
       .global entry
entry:
//       lui   a0, 0xFF000
//       lw    a0, 0(a0)
//       lui   a1, 0xF0020
//       lw    a1, 8(a1)
//       bne    a0, a1, shadow_wfi
//       lui     a1, 0xF0011
//       lbu     a0, 0(a1)
//       // Check whether exit_loop flag is 1, otherwise jump back to entry
//       beqz   a0, entry
//       lw     a0, 4(a1)
//       jalr   a0
       nop
       nop
wfi_entry:
       nop
       nop
       wfi
       j wfi_entry
       nop
       nop
single_boot:
       //Program Counter -> dpc Control & Status Register
       lui   a0, %hi(SAFE_WRAPPER_CTRL_BASEADDRESS)
       lw    a0, SAFE_WRAPPER_CTRL_ENTRY_ADDRESS_REG_OFFSET(a0)          //Base Address CPU Private Registers
       csrw dpc, a0

       //Resume//
       dret


//----------------DEBUG ROM PART----------------//
//----------------------------------------------//
#include "encoding.h"
#define SND_SCRATCH 1
// The debugger can assume as second scratch register.
// These are implementation-specific addresses in the Debug Module
#define HALTED    0x100
#define GOING     0x108
#define RESUMING  0x110
#define EXCEPTION 0x118

// Region of memory where each hart has 1
// byte to read.
#define FLAGS 0x400
#define FLAG_GO     0
#define FLAG_RESUME 1

#include "encoding.h"
#define SND_SCRATCH 1

        // Entry location on ebreak, Halt, or Breakpoint
        // It is the same for all harts. They branch when
        // their GO or RESUME bit is set.
.section .debug_entry

       .global debug_entry
       .global debug_exception

debug_entry:
       csrw CSR_DSCRATCH1, a0       // Save a0 to allow loading arbitrary DM base
       csrw CSR_DSCRATCH0, s0       // Save s0 to allow signaling MHARTID
       lui   a0, %hi(SAFE_WRAPPER_CTRL_BASEADDRESS)
       lw    a0, SAFE_WRAPPER_CTRL_EXTERNAL_DEBUG_REQ_REG_OFFSET(a0)          //Base Address CPU Private Registers

       // Check whether debug_ext_req flag is 1, otherwise jump back to halt_switch routine Todo: Choose better way to reduce
       //cycles
       beqz    a0, halt_boot
       xori     a0 ,a0, 0x2 //Mask applied to see if its Single Debug boot
       beqz     a0, single_boot

//        j single_boot
        // This fence is required because the execution may have written something
        // into the Abstract Data or Program Buffer registers.
//       lui   a0, 0xF0020
//       sw  zero,16(a0)
       fence
#ifdef SND_SCRATCH
//        csrw CSR_DSCRATCH1, a0       // Save a0 to allow loading arbitrary DM base
       lui a0, 0x10000             // Load Upper Immediate Base Address of the Debug Module.
       li  s0, 0x10000830
       jr  s0
       nop
#endif
/*
        // We continue to let the hart know that we are halted in order that
        // a DM which was reset is still made aware that a hart is halted.
        // We keep checking both whether there is something the debugger wants
        // us to do, or whether we should resume.
debug_entry_loop:
        csrr s0, CSR_MHARTID
#ifdef SND_SCRATCH
        sw   s0, HALTED(a0)
        add  s0, s0, a0
#else
        sw   s0, HALTED(zero)
#endif
        lbu  s0, FLAGS(s0) // 1 byte flag per hart. Only one hart advances here.
        andi s0, s0, (1 << FLAG_GO)
        bnez s0, debug_going
        csrr s0, CSR_MHARTID
#ifdef SND_SCRATCH
        add  s0, s0, a0
#endif
        lbu  s0, FLAGS(s0) // multiple harts can resume  here
        andi s0, s0, (1 << FLAG_RESUME)
        bnez s0, debug_resume
        jal  zero, debug_entry_loop

_debug_exception:
        // We can only get here due to an exception while in debug mode. Hence,
        // we do not need to save a0 to a scratch register as it has already
        // been saved on debug entry.
#ifdef SND_SCRATCH
        auipc a0, 0                  // Get POC
        srli a0, a0, 12              // And throw away lower 12 bits to get the DM base
        slli a0, a0, 12
        sw   zero, EXCEPTION(a0)     // Let debug module know you got an exception.
        // It is safe to always restore the scratch registers here as they must
        // have been saved on debug entry. Restoring them here avoids issues
        // with registers being overwritten by exceptions occuring during
        // program buffer execution.
        csrr a0, CSR_DSCRATCH1       // Restore a0 here
#else
        sw   zero, EXCEPTION(zero)     // Let debug module know you got an exception.
#endif
        csrr s0, CSR_DSCRATCH0       // Restore s0 here
        ebreak

debug_going:
#ifdef SND_SCRATCH
        sw zero, GOING(a0)          // When debug module sees this write, the GO flag is reset.
        csrr a0, CSR_DSCRATCH1      // Restore a0 here
#else
        sw zero, GOING(zero)          // When debug module sees this write, the GO flag is reset.
#endif
        csrr s0, CSR_DSCRATCH0      // Restore s0 here
        jal zero, whereto
_debug_resume:
        csrr s0, CSR_MHARTID
#ifdef SND_SCRATCH
        sw   s0, RESUMING(a0)   // When Debug Module sees this write, the RESUME flag is reset.
        csrr a0, CSR_DSCRATCH1  // Restore a0 here
#else
        sw   s0, RESUMING(zero)   // When Debug Module sees this write, the RESUME flag is reset.
#endif
        csrr s0, CSR_DSCRATCH0  // Restore s0 here
        dret

        // END OF ACTUAL "ROM" CONTENTS. BELOW IS JUST FOR LINKER SCRIPT.

.section .whereto
whereto:
        nop
        // Variable "ROM" This is : jal x0 abstract, jal x0 program_buffer,
        //                or jal x0 resume, as desired.
        //                Debug Module state machine tracks what is 'desired'.
*/
halt_boot:
       //Control & Status Register//
       lui   t5, %hi(SAFE_WRAPPER_CTRL_BASEADDRESS)
       lw   t5, SAFE_WRAPPER_CTRL_SAFE_COPY_ADDRESS_REG_OFFSET(t5)

       // csr mstatus
       lw   t6, 0(t5)
       csrw mstatus, t6

       // csr mie
       lw   t6, 4(t5)
       csrw mie, t6

       // csr mtvec
       lw   t6, 8(t5)
       csrw mtvec, t6

       // csr mepc
       lw   t6, 12(t5)
       csrw mepc, t6

       // csr mtval
       lw   t6, 16(t5)
       csrw mtval, t6

       //x1
       lw   ra, 20(t5)

       //x2
       lw   sp, 24(t5)

       //x3
       lw   gp, 28(t5)

       //x4
       lw   tp, 32(t5)

       //**Recovery STACK**/

       lui  t0, %hi(SAFE_WRAPPER_CTRL_BASEADDRESS)     //if not equal a 0 restore de actual stack
       lw   t1, SAFE_WRAPPER_CTRL_DMR_REC_REG_OFFSET(t0)
       fence
       bnez t1,  store_stack
load_register:
       //x5
       lw   t0, 36(t5)

       //x6
       lw   t1, 40(t5)

       //x7
       lw   t2, 44(t5)

       //x8
       lw   s0, 48(t5)

       //x9
       lw   s1, 52(t5)

       //x10
       lw   a0, 56(t5)

       //x11
       lw   a1, 60(t5)

       //x12
       lw   a2, 64(t5)

       //x13
       lw   a3, 68(t5)

       //x14
       lw   a4, 72(t5)

       //x15
       lw   a5, 76(t5)

       //x16
       lw   a6, 80(t5)

       //x17
       lw   a7, 84(t5)

       //x18
       lw   s2, 88(t5)

       //x19
       lw   s3, 92(t5)

       //x20
       lw   s4, 96(t5)

       //x21
       lw   s5, 100(t5)

       //x22
       lw   s6, 104(t5)

       //x23
       lw   s7, 108(t5)

       //x24
       lw   s8, 112(t5)

       //x25
       lw   s9, 116(t5)

       //x26
       lw   s10, 120(t5)

       //x27
       lw   s11, 124(t5)

       //x28
       lw   t3, 128(t5)

       //x29
       lw   t4, 132(t5)

       //PC
       //Program Counter//
       lw   t6, 144(t5)

       //Ensure the read data dpc is performed before instruction bus.
       fence
       //Program Counter -> dpc Control & Status Register
       csrw dpc, t6

       //x31
       lw   t6, 140(t5)

       //x30
       lw   t5, 136(t5)

       //Resume//
       dret


       //
       //Loop//

       nop
       nop
       nop
       nop
       jal zero, halt_boot

store_stack:
                                                                           //Actual Base Stack Pointer from checkpoint store in sp
       lw   t1, SAFE_WRAPPER_CTRL_INITIAL_STACK_ADDR_REG_OFFSET(t0)        //Base Stack Pointer from the begining of the Program main
       fence
       beq  sp, t1, load_register  //Compare addr stack value for sp and base intial sp
       addi t2, t5, 148 //Store addr from beginng of the stack store in the secure place
load_stack:
       lw   t4, 0(t2)
       sw   t4, 0(sp)
       beq  sp, t1, restore_sp  //Compare addr stack value for sp and base intial sp
       addi t2, t2, 4    //Upload 1 position
       addi sp, sp, 4    //Upload 1 position
       j    load_stack
       nop
       nop
restore_sp:
       lw   sp, 24(t5)
       j    load_register
       nop
       nop




//Loop until HALT/*
//.section .shadow_wfi
//shadow_wfi:
//       nop
//       nop
//       nop
//       wfi
//       nop
//       nop
//       nop
//       j shadow_wfi