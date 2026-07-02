// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)
  
#include <stdio.h>
#include <stdlib.h>
#include "csr.h"
#include "csr_registers.h"
#include "CB_Safety.h"

#define SIGNATURE ((volatile uint32_t *)0x0306A000)


int main(int argc, char *argv[]) 
{

        //Enter Safe mode (TCLS_MODE DCLS_MODE LOCKSTEP_MODE)

        int a, b, c;
        Safe_Activate(DCLS_MODE);
        a = 5;
        b = 10;

        //Checkpoint for DCLS configuration
        Store_Checkpoint();

        //Exit Safe mode (MASTER_CORE0 MASTER_CORE1 MASTER_CORE2)
        c = a + b;
        Safe_Stop(MASTER_CORE2); 

        // Safe_Activate(TCLS_MODE);

        // Store_Checkpoint();

        // e = d + d;

        // Safe_Stop(MASTER_CORE2);

         /*
        * Memory signature for Cheshire verification
        */
        /*
     * Memory signature for Cheshire verification
     */
        SIGNATURE[0] = 0xDEADBEEF;  // main reached
        SIGNATURE[1] = a;           // 5
        SIGNATURE[2] = b;           // 10
        SIGNATURE[3] = c;           // 15
        SIGNATURE[4] = 0xCAFEBABE;  // computation completed

        return 0;
}