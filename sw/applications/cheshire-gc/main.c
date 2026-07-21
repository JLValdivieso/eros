// Copyright 2026 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Jonathan Lopez-Valdivieso (jonathan.lvaldivieso@upm.es)
//
// Generic compute-kernel catalog.
// EROS offers a menu of reusable fixed-point kernels that any embedded control
// system needs. Several INDEPENDENT Zephyr tasks (different subsystems, each
// with its own criticality) invoke a kernel, passing the FT mode that matches
// their criticality. Unlike the pipeline, these calls are not chained: they are
// independent requests that the RTOS arbitrates onto the single island.
//
//   task_id 1  DOTPROD  (e.g. sensor fusion)
//   task_id 2  FIR      (e.g. signal conditioning)
//   task_id 3  PID      (e.g. actuator control)     <- typically critical -> TMR
//   task_id 4  CRC      (e.g. message integrity)     <- security -> DCLS
//
// The caller picks the mode; the same catalog serves SINGLE, DCLS and TMR.
//
// Mailbox: MBX[0]status MBX[1]task MBX[2]ft_mode MBX[3]n MBX[4]argp MBX[5]scalar
//          MBX[6]out0 MBX[7]out1 MBX[8]verdict

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "csr.h"
#include "csr_registers.h"
#include "CB_Safety.h"

#define MBX ((volatile int32_t *)0x0306A000)
#define MBX_RUNNING 0x00000002
#define MBX_DONE    0x0D09E000

#define K_DOTPROD 1
#define K_FIR     2
#define K_PID     3
#define K_CRC     4
#define V_OK      0x0000A00D
#define V_BADTASK 0x0000BAD0

// Fault injection 
#define EROS_FAULT_INJECT 1


#ifdef EROS_FAULT_INJECT
#include "base_address.h"
#include "CPU_Private_regs.h"
#define INTERNAL_PRIVATE_REG_ID (CPU_PRIVATE_CORE_ID_CORE_ID_OFFSET + PRIVATE_REG_BASEADDRESS)
#define EROS_INJECT_ADDR        0x0306A100
static void eros_maybe_inject(int32_t *acc)
{
    volatile unsigned int *inj=(volatile unsigned int *)EROS_INJECT_ADDR;
    volatile unsigned int *cid=(volatile unsigned int *)INTERNAL_PRIVATE_REG_ID;

    if (inj[0]==1u && inj[1]==0u) {
        inj[0] = 0; 
        // Left-Shift 2 bits. Useful for DMR mode with 0x5 mask and TMR mode
        // Core0 (001) -> (000)
        // Core1 (010) -> (000)
        // Core2 (100) -> (001) Erroneous value
        *acc = *acc + (int32_t)((*cid)>>2);
    }
}
#endif

static int32_t k_dotprod(const int32_t *buf,int32_t n,int32_t *out0)
{
    int32_t acc=0;

#ifdef EROS_FAULT_INJECT
    eros_maybe_inject(&acc);
#endif
    for (int32_t i=0;i<n;i++) {
        acc += (buf[2*i]*buf[2*i+1])>>8;
    }
    *out0=acc; 

    return V_OK;
}

static int32_t k_fir(const int32_t *buf,int32_t n,int32_t *out0)
{
    int32_t acc=0;
#ifdef EROS_FAULT_INJECT
    eros_maybe_inject(&acc);
#endif
    const int32_t *x=buf,*h=buf+n;
    for (int32_t i=0;i<n;i++) {
        acc += (x[i]*h[i])>>8;
    }
    *out0=acc; 

    return V_OK;
}

static int32_t k_pid(const int32_t *buf,int32_t *out0,int32_t *out1)
{
    int32_t Kp=buf[0],Ki=buf[1],Kd=buf[2],sp=buf[3],meas=buf[4];
    int32_t integ=buf[5],err_prev=buf[6];
    int32_t guard=0;
#ifdef EROS_FAULT_INJECT
    eros_maybe_inject(&guard);
#endif
    int32_t err=sp-meas;
    integ += (Ki*err)>>8;
    int32_t deriv=(Kd*(err-err_prev))>>8;
    int32_t u=((Kp*err)>>8) + integ + deriv + guard;
    if (u>10000) u=10000; 
    if (u<-10000) u=-10000;
    *out0=u; 
    *out1=integ; 

    return V_OK;
}

static int32_t k_crc(const int32_t *buf,int32_t n,int32_t *out0)
{
    uint32_t crc=0xFFFFFFFFu; int32_t guard=0;
#ifdef EROS_FAULT_INJECT
    eros_maybe_inject(&guard);
#endif
    for (int32_t i=0;i<n;i++){
        crc ^= (uint32_t)buf[i] ^ (uint32_t)guard;
        for (int b=0;b<32;b++) crc = (crc&1u)?(crc>>1)^0xEDB88320u:(crc>>1);
    }
    *out0=(int32_t)(crc^0xFFFFFFFFu); 
    
    return V_OK;
}

int main(int argc, char *argv[])
{
    int32_t task=MBX[1], ft_mode=MBX[2], n=MBX[3];
    const int32_t *argp=(const int32_t *)(uintptr_t)MBX[4];

    int32_t out0=0,out1=0,verdict=V_BADTASK;
    MBX[0]=MBX_RUNNING;

    if(ft_mode == SINGLE_MODE){
        switch (task){
        case K_DOTPROD: verdict=k_dotprod(argp,n,&out0); break;
        case K_FIR:     verdict=k_fir(argp,n,&out0);     break;
        case K_PID:     verdict=k_pid(argp,&out0,&out1); break;
        case K_CRC:     verdict=k_crc(argp,n,&out0);     break;
        default: break;
        }
    } else {
        Safe_Activate(ft_mode);   // mode = caller's criticality
        Store_Checkpoint();
        switch (task){
            case K_DOTPROD: verdict=k_dotprod(argp,n,&out0); break;
            case K_FIR:     verdict=k_fir(argp,n,&out0);     break;
            case K_PID:     verdict=k_pid(argp,&out0,&out1); break;
            case K_CRC:     verdict=k_crc(argp,n,&out0);     break;
            default: break;
        }
        Safe_Stop(MASTER_CORE0);
    }

    MBX[6]=out0; MBX[7]=out1; MBX[8]=verdict;
    MBX[0]=MBX_DONE;
    return 0;
}
