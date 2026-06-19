// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)

#include "CB_Safety.h"

//TODO: Evalue the use of others internal register for the safety functions
void Safe_Activate(unsigned int mode){

        asm volatile ("addi sp,sp,-16");     //Store in stack t5, t6
        asm volatile ("sw   t5,12(sp)");
        asm volatile ("sw   t6,8(sp)");

     //Starting Configuration
        asm volatile("li   t5, %0" : : "i" (SAFE_WRAPPER_CTRL_BASEADDRESS));
        asm volatile("lw t6, %0(t5)" : : "i" (SAFE_WRAPPER_CTRL_SAFE_CONFIGURATION_REG_OFFSET));
        asm volatile("bnez t6, _exit_Safe_Activate");
     
     //Passed argument
        asm volatile("sw a0, %0(t5)" : : "i" (SAFE_WRAPPER_CTRL_SAFE_CONFIGURATION_REG_OFFSET));
    
    //Control & Status Register
    //Set Base Address
        asm volatile("li   t5, %0" : : "i" (SAFE_WRAPPER_CTRL_BASEADDRESS));
        asm volatile("lw        t5,%0(t5)" :: "i" (SAFE_WRAPPER_CTRL_SAFE_COPY_ADDRESS_REG_OFFSET));
    //Machine Status
    //mstatus   0x300
        asm volatile("csrr t6, mstatus");
        asm volatile("sw    t6,0(t5)");

    //Machine Interrupt Enable
    //mie       0x304
        asm volatile("csrr t6, mie");
        asm volatile("sw    t6,4(t5)"); 

    //Machine Trap-Vector
    //mtvec     0x305
        asm volatile("csrr t6, mtvec");
        asm volatile("sw    t6,8(t5)");

    //Machine Exception Program Counter
    //mepc      0x341
        asm volatile("csrr t6, mepc");
        asm volatile("sw    t6,12(t5)"); 

    //Machine Trap Value Register
    //mtval     0x343
        asm volatile("csrr t6, mtval");
        asm volatile("sw    t6,16(t5)");


    //Register File
        //x1    ra
        asm volatile("sw ra, 20(t5)");

        //x2    sp
        asm volatile("sw sp, 24(t5)");

        //x3    gp
        asm volatile("sw gp, 28(t5)"); 

        //x4    tp
        asm volatile("sw tp, 32(t5)");

        //x5    t0
        asm volatile("sw t0, 36(t5)");   

        //x6    t1
        asm volatile("sw t1, 40(t5)");       

        //x7    t2
        asm volatile("sw t2, 44(t5)");

        //x8   s0/fp
        asm volatile("sw s0, 48(t5)");

        //x9    s1
        asm volatile("sw s1, 52(t5)");

        //x10   a0 
        asm volatile("sw a0, 56(t5)");

        //x11   a1 
        asm volatile("sw a1, 60(t5)");

        //x12   a2 
        asm volatile("sw a2, 64(t5)");

        //x13   a3 
        asm volatile("sw a3, 68(t5)");


        //x14   a4 
        asm volatile("sw a4, 72(t5)");

        //x15   a5 
        asm volatile("sw a5, 76(t5)");

        //x16   a6 
        asm volatile("sw a6, 80(t5)");

        //x17   a7 
        asm volatile("sw a7, 84(t5)");

        //x18   s2 
        asm volatile("sw s2, 88(t5)");

        //x19   s3 
        asm volatile("sw s3, 92(t5)");

        //x20   s4 
        asm volatile("sw s4, 96(t5)");

        //x21   s5 
        asm volatile("sw s5, 100(t5)");

        //x22   s6 
        asm volatile("sw s6, 104(t5)");

        //x23   s7 
        asm volatile("sw s7, 108(t5)");

        //x24   s8 
        asm volatile("sw s8, 112(t5)");

        //x25   s9 
        asm volatile("sw s9, 116(t5)");

        //x26   s10 
        asm volatile("sw s10, 120(t5)");

        //x27   s11 
        asm volatile("sw s11, 124(t5)");

        //x28   t3 
        asm volatile("sw t3, 128(t5)");

        //x29   t4 
        asm volatile("sw t4, 132(t5)"); 

        asm volatile ("sw   t5,12(sp)");
        //x30   t5  
        asm volatile("lw   t6,12(sp)"); //Load from stack true value of t5
        asm volatile("sw t5, 136(t5)"); 

        //x31   t6 
        asm volatile("lw   t6,8(sp)"); //Load from stack true value of t6
        asm volatile("sw t6, 140(t5)");

        //Master Sync Priv Reg
        asm volatile("li   t5, %0" : : "i" (SAFE_WRAPPER_CTRL_BASEADDRESS));
        asm volatile("li   t6, 0x1");
        asm volatile("sw t6, %0(t5)" : : "i" (SAFE_WRAPPER_CTRL_INITIAL_SYNC_MASTER_REG_OFFSET));

        asm volatile(".ALIGN(2)");
        asm volatile("li   t5, %0" : : "i" (SAFE_WRAPPER_CTRL_BASEADDRESS));
        asm volatile("lw        t5,%0(t5)" :: "i" (SAFE_WRAPPER_CTRL_SAFE_COPY_ADDRESS_REG_OFFSET));
        //PC Program Counter
        asm volatile("auipc t6, 0");
        asm volatile("sw t6, 144(t5)");

        asm volatile("fence");

        __asm__ volatile(".word 0x00000013");
        __asm__ volatile(".word 0x00000013");
        __asm__ volatile(".word 0x00000013");
        __asm__ volatile(".word 0x00000013");
                asm volatile("wfi");
        __asm__ volatile(".word 0x00000013");
        __asm__ volatile(".word 0x00000013");
        __asm__ volatile(".word 0x00000013");

        //Reset Values 
        asm volatile("li   t5, %0" : : "i" (SAFE_WRAPPER_CTRL_BASEADDRESS));
        asm volatile("sw zero, %0(t5)" : : "i" (SAFE_WRAPPER_CTRL_INITIAL_SYNC_MASTER_REG_OFFSET));
        asm volatile("li   t5, %0" : : "i" (PRIVATE_REG_BASEADDRESS));
        asm volatile("sw zero, %0(t5)" : : "i" (CPU_PRIVATE_HART_INTC_ACK_REG_OFFSET));        

        //Reference for if-else (already in TMR mode or not checking configuration reg)
        asm volatile(".global _exit_Safe_Activate");
        asm volatile("_exit_Safe_Activate:");

        //Bring Real Values from Stack
        asm volatile("lw  t6,8(sp)");
        asm volatile("lw  t5,12(sp)");
        asm volatile("addi sp,sp,16");
}


void Safe_Stop(unsigned int master){
volatile unsigned int *Safe_config_reg = (volatile unsigned int *)(SAFE_WRAPPER_CTRL_BASEADDRESS);
        if(*Safe_config_reg == 0x1 || *Safe_config_reg == 0x2 || *Safe_config_reg == 0x3){
                if (*(Safe_config_reg+3) == 0x1)
                        Set_Critical_Section(NONE_CRITICAL_SECTION);
                *(Safe_config_reg+2) = master;
                *(Safe_config_reg) = 0x0;
                asm volatile("fence");
                asm volatile("wfi");
                __asm__ volatile(".word 0x00000013");
                __asm__ volatile(".word 0x00000013");
        }
}

void handler_tmr_recoverysync(void){ 

        asm volatile("addi    sp,sp,-16");
        asm volatile("sw      a4,12(sp)");
        asm volatile("sw      a5,8(sp)");
        
        asm volatile ("li a4,1");          //Operate with address INTC ACK
        asm volatile ("li a5, %0" : : "i" (PRIVATE_REG_BASEADDRESS));
        asm volatile ("sw  a4,%0(a5)": : "i" (CPU_PRIVATE_HART_INTC_ACK_REG_OFFSET));

        asm volatile("lw      a4,12(sp)");
        asm volatile("lw      a5,8(sp)");
  
        //Push Stack//
        //Register File
        //x1    ra
        asm volatile("sw ra, -4(sp)");
        //x2    sp
        asm volatile("sw sp, -8(sp)");
        //x3    gp
        asm volatile("sw gp, -12(sp)"); 
        //x4    tp
        asm volatile("sw tp, -16(sp)");
        //x5    t0
        asm volatile("sw t0, -20(sp)");   
        //x6    t1
        asm volatile("sw t1, -24(sp)");       
        //x7    t2
        asm volatile("sw t2, -28(sp)");
        //x8   s0/fp
        asm volatile("sw s0, -32(sp)");
        //x9    s1
        asm volatile("sw s1, -36(sp)");
        //x10   a0 
        asm volatile("sw a0, -40(sp)");
        //x11   a1 
        asm volatile("sw a1, -44(sp)");
        //x12   a2 
        asm volatile("sw a2, -48(sp)");
        //x13   a3 
        asm volatile("sw a3, -52(sp)");
        //x14   a4 
        asm volatile("sw a4, -56(sp)");
        //x15   a5 
        asm volatile("sw a5, -60(sp)");
        //x16   a6 
        asm volatile("sw a6, -64(sp)");
        //x17   a7 
        asm volatile("sw a7, -68(sp)");
        //x18   s2 
        asm volatile("sw s2, -72(sp)");
        //x19   s3 
        asm volatile("sw s3, -76(sp)");
        //x20   s4 
        asm volatile("sw s4, -80(sp)");
        //x21   s5 
        asm volatile("sw s5, -84(sp)");
        //x22   s6 
        asm volatile("sw s6, -88(sp)");
        //x23   s7 
        asm volatile("sw s7, -92(sp)");
        //x24   s8 
        asm volatile("sw s8, -96(sp)");
        //x25   s9 
        asm volatile("sw s9, -100(sp)");
        //x26   s10 
        asm volatile("sw s10, -104(sp)");
        //x27   s11 
        asm volatile("sw s11, -108(sp)");
        //x28   t3 
        asm volatile("sw t3, -112(sp)");
        //x29   t4 
        asm volatile("sw t4, -116(sp)"); 
        //x30   t5  
        asm volatile("sw t5, -120(sp)"); 
        //x31   t6 
        asm volatile("sw t6, -124(sp)");  

        //Control & Status Register
        //mstatus   0x300
        asm volatile("csrr t6, mstatus");
        asm volatile("sw    t6,-128(sp)");
        //Machine Interrupt Enable
        //mie       0x304
        asm volatile("csrr t6, mie");
        asm volatile("sw    t6,-132(sp)"); 
        //mtvec     0x305
        asm volatile("csrr t6, mtvec");
        asm volatile("sw    t6,-136(sp)");
        //mepc      0x341
        asm volatile("csrr t6, mepc");
        asm volatile("sw    t6,-140(sp)"); 
        //mtval     0x343
        asm volatile("csrr t6, mtval");
        asm volatile("sw    t6,-144(sp)");


        //Pop Stack//
        //Control & Status Register
        //mstatus   0x300
        asm volatile("lw    t6,-128(sp)");
        asm volatile("csrw mstatus, t6");
        //Machine Interrupt Enable
        //mie       0x304
        asm volatile("lw    t6,-132(sp)"); 
        asm volatile("csrw mie, t6");
        //mtvec     0x305
        asm volatile("lw    t6,-136(sp)");
        asm volatile("csrw mtvec, t6");
        //mepc      0x341
        asm volatile("lw    t6,-140(sp)");
        asm volatile("csrw mepc, t6"); 
        //mtval     0x343
        asm volatile("lw    t6,-144(sp)");
        asm volatile("csrw mtval, t6");  


        //Register File
        //x1    ra
        asm volatile("lw ra, -4(sp)");
        //x2    sp
        asm volatile("lw sp, -8(sp)");
        //x3    gp
        asm volatile("lw gp, -12(sp)"); 
        //x4    tp
        asm volatile("lw tp, -16(sp)");
        //x5    t0
        asm volatile("lw t0, -20(sp)");   
        //x6    t1
        asm volatile("lw t1, -24(sp)");       
        //x7    t2
        asm volatile("lw t2, -28(sp)");
        //x8   s0/fp
        asm volatile("lw s0, -32(sp)");
        //x9    s1
        asm volatile("lw s1, -36(sp)");
        //x10   a0 
        asm volatile("lw a0, -40(sp)");
        //x11   a1 
        asm volatile("lw a1, -44(sp)");
        //x12   a2 
        asm volatile("lw a2, -48(sp)");
        //x13   a3 
        asm volatile("lw a3, -52(sp)");
        //x14   a4 
        asm volatile("lw a4, -56(sp)");
        //x15   a5 
        asm volatile("lw a5, -60(sp)");
        //x16   a6 
        asm volatile("lw a6, -64(sp)");
        //x17   a7 
        asm volatile("lw a7, -68(sp)");
        //x18   s2 
        asm volatile("lw s2, -72(sp)");
        //x19   s3 
        asm volatile("lw s3, -76(sp)");
        //x20   s4 
        asm volatile("lw s4, -80(sp)");
        //x21   s5 
        asm volatile("lw s5, -84(sp)");
        //x22   s6 
        asm volatile("lw s6, -88(sp)");
        //x23   s7 
        asm volatile("lw s7, -92(sp)");
        //x24   s8 
        asm volatile("lw s8, -96(sp)");
        //x25   s9 
        asm volatile("lw s9, -100(sp)");
        //x26   s10 
        asm volatile("lw s10, -104(sp)");
        //x27   s11 
        asm volatile("lw s11, -108(sp)");
        //x28   t3 
        asm volatile("lw t3, -112(sp)");
        //x29   t4 
        asm volatile("lw t4, -116(sp)"); 
        //x30   t5  
        asm volatile("lw t5, -120(sp)"); 
        //x31   t6 
        asm volatile("lw t6, -124(sp)");  

        asm volatile ("li a5, %0" : : "i" (PRIVATE_REG_BASEADDRESS));
        asm volatile("sw  zero,%0(a5)": : "i" (CPU_PRIVATE_HART_INTC_ACK_REG_OFFSET)); 
        asm volatile("lw  a5,8(sp)");
        asm volatile("addi sp,sp,16");
}

void handler_safe_fsm(void) { 
        asm volatile("addi    sp,sp,-16");
        asm volatile("sw      t5,12(sp)");
        asm volatile("sw      t6,8(sp)");

        asm volatile("li t5, %0" : : "i"    (PRIVATE_REG_BASEADDRESS));
        asm volatile("li t6, 0x1");
        asm volatile("sw t6,%0(t5)": : "i" (CPU_PRIVATE_HART_INTC_ACK_REG_OFFSET));
        asm volatile("sw zero,%0(t5)": : "i" (CPU_PRIVATE_HART_INTC_ACK_REG_OFFSET));             

        asm volatile("lw     t5,12(sp)");
        asm volatile("lw     t6,8(sp)");
        asm volatile("addi   sp,sp,16");
}

void handler_tmr_dmcontext_copy(void){
        asm volatile ("addi sp,sp,-16");     //Store in stack a4, a5
        asm volatile ("sw   a4,12(sp)");
        asm volatile ("sw   a5,8(sp)");
        
        asm volatile ("li a4,1");          //Operate with address
        asm volatile ("li a5, %0" : : "i" (PRIVATE_REG_BASEADDRESS));
        asm volatile ("sw  a4,4(a5)");
        asm volatile ("sw  zero,4(a5)");
                                                //Restore values 
        asm volatile ("lw  a4,12(sp)");
        asm volatile ("lw  a5,8(sp)");

    //Control & Status Register
    //Set Base Address
        asm volatile("li   t5, %0" : : "i" (SAFE_WRAPPER_CTRL_BASEADDRESS));
        asm volatile("lw        t5,%0(t5)" :: "i" (SAFE_WRAPPER_CTRL_SAFE_COPY_ADDRESS_REG_OFFSET));
    //Machine Status
    //mstatus   0x300
        asm volatile("csrr t6, mstatus");
        asm volatile("ori t6, t6,0x08;");       //Activate mstatus mie 
        asm volatile("sw   t6,0(t5)");

    //Machine Interrupt Enable
    //mie       0x304
        asm volatile("csrr t6, mie");
        asm volatile("sw    t6,4(t5)"); 

    //Machine Trap-Vector
    //mtvec     0x305
        asm volatile("csrr t6, mtvec");
        asm volatile("sw    t6,8(t5)");

    //Machine Exception Program Counter
    //mepc      0x341
        asm volatile("csrr t6, mepc");
        asm volatile("sw    t6,12(t5)"); 

        asm volatile("li   t6, %0" : : "i" (BOOT_OFFSET));     //PC -> wfi Debug_Boot_ROM
        asm volatile("csrw  mepc, t6");
    //Machine Trap Value Register
    //mtval     0x343
        asm volatile("csrr t6, mtval");
        asm volatile("sw    t6,16(t5)");


    //Register File
        //x1    ra
        asm volatile("sw ra, 20(t5)");

        //x2    sp
        asm volatile("addi    t6,sp,16");
        asm volatile("sw      t6,24(t5)");      //Restore de sp before the function

        //x3    gp
        asm volatile("sw gp, 28(t5)"); 

        //x4    tp
        asm volatile("sw tp, 32(t5)");

        //x5    t0
        asm volatile("sw t0, 36(t5)");   

        //x6    t1
        asm volatile("sw t1, 40(t5)");       

        //x7    t2
        asm volatile("sw t2, 44(t5)");

        //x8   s0/fp
        asm volatile("sw s0, 48(t5)");

        //x9    s1
        asm volatile("sw s1, 52(t5)");

        //x10   a0
        asm volatile("sw a0, 56(t5)");

        //x11   a1
        asm volatile("sw a1, 60(t5)");

        //x12   a2
        asm volatile("sw a2, 64(t5)");

        //x13   a3
        asm volatile("sw a3, 68(t5)");


        //x14   a4
        asm volatile("sw a4, 72(t5)");

        //x15   a5
        asm volatile("sw a5, 76(t5)");

        //x16   a6
        asm volatile("sw a6, 80(t5)");

        //x17   a7
        asm volatile("sw a7, 84(t5)");

        //x18   s2
        asm volatile("sw s2, 88(t5)");

        //x19   s3
        asm volatile("sw s3, 92(t5)");

        //x20   s4
        asm volatile("sw s4, 96(t5)");

        //x21   s5
        asm volatile("sw s5, 100(t5)");

        //x22   s6
        asm volatile("sw s6, 104(t5)");

        //x23   s7
        asm volatile("sw s7, 108(t5)");

        //x24   s8
        asm volatile("sw s8, 112(t5)");

        //x25   s9
        asm volatile("sw s9, 116(t5)");

        //x26   s10
        asm volatile("sw s10, 120(t5)");

        //x27   s11
        asm volatile("sw s11, 124(t5)");

        //x28   t3
        asm volatile("sw t3, 128(t5)");

        //x29   t4
        asm volatile("sw t4, 132(t5)"); 

        //PC -> 0xDebug_BootAddress + 0x200
        asm volatile("li   t6, %0" : : "i" (BOOT_OFFSET));
        asm volatile("sw t6, 144(t5)");
        //x30   t5
        asm volatile("sw t5, 136(t5)"); 
        //x31   t6
        asm volatile("sw t6, 140(t5)");

        asm volatile("addi      sp,sp,16"); //Restore stack pointer

}
void handler_tmr_dmshsync(void){
        asm volatile("addi    sp,sp,-16");
        asm volatile("sw      t5,12(sp)");
        asm volatile("sw      t6,8(sp)");

        asm volatile("li t5, %0" : : "i"    (PRIVATE_REG_BASEADDRESS));
        asm volatile("li t6, 0x1");
        asm volatile("sw t6,%0(t5)": : "i" (CPU_PRIVATE_HART_INTC_ACK_REG_OFFSET));
        asm volatile("sw zero,%0(t5)": : "i" (CPU_PRIVATE_HART_INTC_ACK_REG_OFFSET));             

    //Control & Status Register
    //Set Base Address
        asm volatile("li   t5, %0" : : "i" (SAFE_WRAPPER_CTRL_BASEADDRESS));
        asm volatile("lw   t5,%0(t5)" :: "i" (SAFE_WRAPPER_CTRL_SAFE_COPY_ADDRESS_REG_OFFSET));

    //Machine Exception Program Counter
    //mepc      0x341
        asm volatile("sw t5, -4(sp)");
        asm volatile("lw t5, 12(t5)");
        asm volatile("csrw mepc, t5"); 
        asm volatile("lw t5, -4(sp)");

        asm volatile("lw     t5,12(sp)");
        asm volatile("lw     t6,8(sp)");
        asm volatile("addi   sp,sp,16");
}

void Store_Checkpoint(void){
        asm volatile ("addi sp,sp,-28");     //Store in stack t2, t3, t4, t5, t6
        asm volatile ("sw   t2,24(sp)");
        asm volatile ("sw   t3,20(sp)");
        asm volatile ("sw   t4,16(sp)");
        asm volatile ("sw   t5,12(sp)");
        asm volatile ("sw   t6,8(sp)");
    //Set Base Address
        asm volatile("li   t5, %0" : : "i" (SAFE_WRAPPER_CTRL_BASEADDRESS));
        asm volatile("lw   t4, %0(t5)" :: "i" (SAFE_WRAPPER_CTRL_INITIAL_STACK_ADDR_REG_OFFSET));
        asm volatile("lw        t5,%0(t5)" :: "i" (SAFE_WRAPPER_CTRL_SAFE_COPY_ADDRESS_REG_OFFSET));
    //Check-Stack Pointer

        asm volatile("addi sp,sp,28");
        asm volatile("mv   t2,sp");     //Store external stack in t2
        asm volatile("fence");
        asm volatile ("beq  t2, t4, _checkpoint_store_reg");
        asm volatile ("addi t3, t5, 148 "); //Store addr from beginng of the stack store in the secure place      

        asm volatile(".global _checkpoint_store_stack");
        asm volatile("_checkpoint_store_stack:");
        asm volatile("lw   t6, 0(t2)");
        asm volatile("sw   t6, 0(t3)");
        asm volatile("beq  t2, t4, _checkpoint_store_reg");  //Compare addr stack value for sp and base intial sp
        asm volatile("addi t3, t3, 4");    //Upload 1 position
        asm volatile("addi t2, t2, 4");    //Upload 1 position        
        asm volatile("j          _checkpoint_store_stack");
        asm volatile(".global _checkpoint_store_reg");
        asm volatile("_checkpoint_store_reg:");

    //Control & Status Register
    //Machine Status
    //mstatus   0x300
        asm volatile("csrr t6, mstatus");
        asm volatile("sw   t6,0(t5)");

    //Machine Interrupt Enable
    //mie       0x304
        asm volatile("csrr t6, mie");
        asm volatile("sw    t6,4(t5)"); 

    //Machine Trap-Vector
    //mtvec     0x305
        asm volatile("csrr t6, mtvec");
        asm volatile("sw    t6,8(t5)");

    //Machine Exception Program Counter
    //mepc      0x341
        asm volatile("csrr t6, mepc");
        asm volatile("sw    t6,12(t5)"); 

    //Machine Trap Value Register
    //mtval     0x343
        asm volatile("csrr t6, mtval");
        asm volatile("sw    t6,16(t5)");


    //Register File
        //x1    ra
        asm volatile("sw ra, 20(t5)");

        //x2    sp
        asm volatile("sw      sp,24(t5)");      //Restore de sp before the function
        asm volatile("addi    sp,sp,-28");
        //x3    gp
        asm volatile("sw gp, 28(t5)"); 

        //x4    tp
        asm volatile("sw tp, 32(t5)");

        //x5    t0
        asm volatile("sw t0, 36(t5)");   

        //x6    t1
        asm volatile("sw t1, 40(t5)");       

        //x7    t2
        asm volatile ("lw   t2,24(sp)"); 
        asm volatile("sw t2, 44(t5)");

        //x8   s0/fp
        asm volatile("sw s0, 48(t5)");

        //x9    s1
        asm volatile("sw s1, 52(t5)");

        //x10   a0
        asm volatile("sw a0, 56(t5)");

        //x11   a1
        asm volatile("sw a1, 60(t5)");

        //x12   a2
        asm volatile("sw a2, 64(t5)");

        //x13   a3
        asm volatile("sw a3, 68(t5)");


        //x14   a4
        asm volatile("sw a4, 72(t5)");

        //x15   a5
        asm volatile("sw a5, 76(t5)");

        //x16   a6
        asm volatile("sw a6, 80(t5)");

        //x17   a7
        asm volatile("sw a7, 84(t5)");

        //x18   s2
        asm volatile("sw s2, 88(t5)");

        //x19   s3
        asm volatile("sw s3, 92(t5)");

        //x20   s4
        asm volatile("sw s4, 96(t5)");

        //x21   s5
        asm volatile("sw s5, 100(t5)");

        //x22   s6
        asm volatile("sw s6, 104(t5)");

        //x23   s7
        asm volatile("sw s7, 108(t5)");

        //x24   s8
        asm volatile("sw s8, 112(t5)");

        //x25   s9
        asm volatile("sw s9, 116(t5)");

        //x26   s10
        asm volatile("sw s10, 120(t5)");

        //x27   s11
        asm volatile("sw s11, 124(t5)");

        //x28   t3
        asm volatile ("lw   t3,20(sp)"); 
        asm volatile("sw t3, 128(t5)");

        //x29   t4
        asm volatile ("lw   t4,16(sp)"); 
        asm volatile("sw t4, 132(t5)"); 

        //PC -> 0xDebug_BootAddress + 0x200
        asm volatile("la   t6, _exit_Store_checkpoint");
        asm volatile("sw t6, 144(t5)");
        //x30   t5
        asm volatile ("lw   t6,12(sp)");
        asm volatile("sw t6, 136(t5)"); 

        //x31   t6
        asm volatile ("lw   t6,8(sp)");
        asm volatile("sw t6, 140(t5)");

        asm volatile ("lw   t2,24(sp)"); 
        asm volatile ("lw   t3,20(sp)"); 
        asm volatile ("lw   t4,16(sp)"); 
        asm volatile ("lw   t5,12(sp)");
        asm volatile ("lw   t6,8(sp)");
        asm volatile("addi      sp,sp,28"); //Restore stack pointer

        //Reference for exit store_checkpoint 
        asm volatile(".global _exit_Store_checkpoint");
        asm volatile("_exit_Store_checkpoint:");      
}



void Check_RF(void){
        asm volatile ("addi sp,sp,-20");     //Store in stack a4, a5
        asm volatile ("sw   t4,16(sp)");
        asm volatile ("sw   t5,12(sp)");
        asm volatile ("sw   t6,8(sp)");
                                                //Restore values 
        asm volatile ("lw  a4,12(sp)");
        asm volatile ("lw  a5,8(sp)");


        asm volatile("li t6, %0" : : "i" (CHECK_RAM_ADDRESS));


    //Register File
        //x1    ra
        asm volatile("sw ra, 0(t6)");

        //x2    sp
        asm volatile("addi    t5,sp,20");
        asm volatile("sw      t5,12(t6)");      //Restore de sp before the function

        //x3    gp
        asm volatile("sw gp, 8(t6)"); 

        //x4    tp
        asm volatile("sw tp, 12(t6)");

        //x5    t0
        asm volatile("sw t0, 16(t6)");   

        //x6    t1
        asm volatile("sw t1, 20(t6)");       

        //x7    t2
        asm volatile("sw t2, 24(t6)");

        //x8   s0/fp
        asm volatile("sw s0, 28(t6)");

        //x9    s1
        asm volatile("sw s1, 32(t6)");

        //x10   a0
        asm volatile("sw a0, 36(t6)");

        //x11   a1
        asm volatile("sw a1, 40(t6)");

        //x12   a2
        asm volatile("sw a2, 44(t6)");

        //x13   a3
        asm volatile("sw a3, 48(t6)");


        //x14   a4
        asm volatile("sw a4, 52(t6)");

        //x15   a5
        asm volatile("sw a5, 56(t6)");

        //x16   a6
        asm volatile("sw a6, 60(t6)");

        //x17   a7
        asm volatile("sw a7, 64(t6)");

        //x18   s2
        asm volatile("sw s2, 68(t6)");

        //x19   s3
        asm volatile("sw s3, 72(t6)");

        //x20   s4
        asm volatile("sw s4, 76(t6)");

        //x21   s5
        asm volatile("sw s5, 80(t6)");

        //x22   s6
        asm volatile("sw s6, 84(t6)");

        //x23   s7
        asm volatile("sw s7, 88(t6)");

        //x24   s8
        asm volatile("sw s8, 92(t6)");

        //x25   s9
        asm volatile("sw s9, 96(t6)");

        //x26   s10
        asm volatile("sw s10, 100(t6)");

        //x27   s11
        asm volatile("sw s11, 104(t6)");

        //x28   t3
        asm volatile("sw t3, 108(t6)");

        //x29   t4
        asm volatile("sw t4, 112(t6)"); 

        //x30   t5       
        asm volatile ("lw  t5,12(sp)"); //Restore t5
        asm volatile("sw t5, 116(t6)"); 

        //x31   t6
        asm volatile ("lw   t6,8(sp)"); //Restore t6
        asm volatile("li t5, %0" : : "i" (CHECK_RAM_ADDRESS));     //Set address in t5   
        asm volatile("sw t6, 120(t5)");

        asm volatile ("lw   t5,12(sp)"); //Restore t5
        asm volatile("addi      sp,sp,20"); //Restore stack pointer
}


//Todo adapt this exit to the exit syscall and exit_status
__attribute__((aligned(4))) void _exit(int exit_status){
    volatile unsigned int *END_SW_P = (volatile unsigned int *)(SAFE_WRAPPER_CTRL_BASEADDRESS +
                              SAFE_WRAPPER_CTRL_END_SW_ROUTINE_REG_OFFSET);
    *END_SW_P = 0x1;
    asm volatile("fence");
    asm volatile("wfi");

    while(1)
    asm volatile(".word 0x00000013");
    asm volatile(".word 0x00000013");
    asm volatile(".word 0x00000013");
/**/
}