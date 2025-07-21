// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Luis Waucquez (luis.waucquez.jimenez@upm.es)
  
#include <stdio.h>
#include <stdlib.h>
//#include "csr.h"
//#include "csr_registers.h"
#include "CB_Safety.h"


int main(int argc, char *argv[]) 
{
unsigned int *P = SAFE_WRAPPER_CTRL_BASEADDRESS + CB_HEEP_CTRL_DMR_MASK_REG_OFFSET;
volatile unsigned int *P1 = GLOBAL_BASE_ADDRESS + 0x0002A000;

        /******START******/

//                printf("[IP_CEI]: Hello world!\n");

        //Enter Safe mode (TCLS_MODE DCLS_MODE LOCKSTEP_MODE)
        Safe_Activate(TCLS_MODE);
///        Store_Checkpoint();
//                printf("[TCLS]\n");

        //Checkpoint for DMR configuration
//        Store_Checkpoint();


        //Exit Safe mode (MASTER_CORE0 MASTER_CORE1 MASTER_CORE2)
        Safe_Stop(MASTER_CORE2); 


///                printf("[SINGLE]\n");

        Safe_Activate(LOCKSTEP_MODE);
        
        for (int i=0; i<1000000;i++)
                *P1 = i;
//                printf("[LOCKS]\n");

        Safe_Stop(MASTER_CORE0);



        Safe_Activate(DCLS_MODE);
//        Store_Checkpoint();

//                printf("[DCLS]\n");

        Safe_Stop(MASTER_CORE0);


        *P = CORE12_MASK;

        Safe_Activate(TCLS_MODE);
///        Store_Checkpoint();
//                printf("[TCLS]\n");

        //Checkpoint for DMR configuration
//        Store_Checkpoint();


        //Exit Safe mode (MASTER_CORE0 MASTER_CORE1 MASTER_CORE2)
        Safe_Stop(MASTER_CORE1); 


//               printf("[SINGLE]\n");

        Safe_Activate(LOCKSTEP_MODE);

//                printf("[LOCKS]\n");

        Safe_Stop(MASTER_CORE2);



        Safe_Activate(DCLS_MODE);
//        Store_Checkpoint();

//                printf("[DCLS]\n");

        Safe_Stop(MASTER_CORE2);

//                printf("[SINGLE]\n");
//                printf("[IP_CEI]: Hello world!\n");

        /******END PROGRAM******/
    
        return 0;
}