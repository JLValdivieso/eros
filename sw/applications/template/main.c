// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)
  
#include <stdio.h>
#include <stdlib.h>
#include "csr.h"
#include "csr_registers.h"
#include "CB_Safety.h"

#define SIGNATURE ((volatile uint32_t *)0x0306C000)

void first_signature(void){
        
        volatile int a,b,c;

        Safe_Activate(DCLS_MODE);

        a = 6;
        b = 11;
        c = a + b;

        Store_Checkpoint();

        SIGNATURE[0] = 0xDEADBEEF;  // main reached
        SIGNATURE[1] = a;           // 10

        Safe_Stop(MASTER_CORE2);

        // for (volatile int i = 0; i < 1100; i++);

        asm volatile ("wfi");

        
        SIGNATURE[2] = b;           // 10
        SIGNATURE[3] = c;           // 15
        SIGNATURE[4] = 0xCAFEBABE;  // computation completed

}

void second_signature(void){
        volatile int a,b,c;

        Safe_Activate(DCLS_MODE);

        a = 10;
        b = 20;
        c = a + b;

        Store_Checkpoint();

        SIGNATURE[0] = 0xAAAAAAAA;  // main reached
        SIGNATURE[1] = a;           

        Safe_Stop(MASTER_CORE2);

        // for (volatile int i = 0; i < 1100; i++);

        asm volatile ("wfi");

        
        SIGNATURE[2] = b;           
        SIGNATURE[3] = c;           
        SIGNATURE[4] = 0xBBBBBBBB;  // computation completed
}

int main(int argc, char *argv[]) 
{
        first_signature();

        return 0;
}