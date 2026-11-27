// Copyright 2026 CEIMM UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Jonathan Valdivieso (jonathan.lvaldivieso@upm.es)
//
// Host (Cheshire) side of the EROS N-task preemption test.
// This program runs on the host
//
// Round-robin scheduler with a fixed time slice measured in host cycles:

#include "regs/cheshire.h"
#include "dif/clint.h"
#include "dif/uart.h"
#include "params.h"
#include "util.h"
#include "printf.h"
#include "util_preemptive/eros_tasks_addr.h"
#include "util_preemptive/eros_task_kernels.h"

#include <stdint.h>

// -----------------------------------------------------------------------------
// Test parameters
// -----------------------------------------------------------------------------

#define TIME_SLICE       100000u    // time slice of every task, host cycles
#define PREEMPT_TIMEOUT  2000000u   // max wait for PREEMPT_READY, host cycles
#define MAX_ROUNDS       100000u    // stop the round-robin if tasks never end
#define VERBOSE          1          // print every preemption
#define PREEMPT_LAST_TASK 0         // 1: keep preempting the last task left (stress
                                    //    test of repeated resumes), 0: let it run to the end
#define FAULT_INJECTION  1          // 1: inject one fault in every kernel (see
                                    //    EROS_INJ in eros_task_kernels.h)
#define FAULT_SLICE      4          // arm the fault of a task before this dispatch

// -----------------------------------------------------------------------------
// EROS CSRs
// -----------------------------------------------------------------------------

#define REG32(addr) (*(volatile uint32_t *)(uintptr_t)(addr))

#define EROS_BASE_ADDR 0x03080000

#define SAFE_CONFIGURATION      REG32(EROS_BASE_ADDR + 0x0000)
#define DMR_MASK                REG32(EROS_BASE_ADDR + 0x0004)
#define MASTER_CORE             REG32(EROS_BASE_ADDR + 0x0008)
#define START                   REG32(EROS_BASE_ADDR + 0x0010)
#define EXTERNAL_DEBUG_REQ      REG32(EROS_BASE_ADDR + 0x0014)
#define END_SW_ROUTINE          REG32(EROS_BASE_ADDR + 0x001C)
#define ENTRY_ADDRESS           REG32(EROS_BASE_ADDR + 0x0020)
#define SAFE_COPY_ADDRESS       REG32(EROS_BASE_ADDR + 0x0024)
#define INTERRUPT_CONTROLLER    REG32(EROS_BASE_ADDR + 0x0028)
#define EROS_STATUS             REG32(EROS_BASE_ADDR + 0x002C)
#define DMR_REC                 REG32(EROS_BASE_ADDR + 0x0030)
#define INITIAL_STACK_ADDR      REG32(EROS_BASE_ADDR + 0x0034)
#define PREEMPTIVE_CONTEXT_ADDR REG32(EROS_BASE_ADDR + 0x0038)
#define PREEMPTIVE_CTRL_STATUS  REG32(EROS_BASE_ADDR + 0x003C)

/* PREEMPTIVE_CTRL_STATUS values */
#define PREEMPT_START_TASK      0x0
#define PREEMPT_TRIGGER         0x1
#define PREEMPT_READY           0x3
#define PREEMPT_CONTINUE_TASK   0x4

#define EROS_SIG(i)             REG32(EROS_SIGNATURE_ADDRESS + 4 * (i))

/* handler_preemptive_store_context (PREEMPT_TIMING in CB_Safety.h) resets the
   EROS mcycle at its entry and writes it after the 148 B frame of the context
   slot once the context is saved, so END already holds the handler cycles */
#define PREEMPT_TS_ENTRY(ctx)   REG32((ctx) + 148)  /* not written, stays 0 */
#define PREEMPT_TS_END(ctx)     REG32((ctx) + 152)  /* handler cycles */

// -----------------------------------------------------------------------------
// Scheduler state
// -----------------------------------------------------------------------------

static const eros_task_t tasks[EROS_NTASKS] = EROS_TASK_TABLE;

typedef enum { 
    T_NEW, 
    T_PAUSED, 
    T_DONE 
} task_state_t;

typedef struct {
    task_state_t state;
    uint32_t     slices;         // times it was dispatched
    uint32_t     preemptions;    // times its context was saved
    uint32_t     progress;       // last progress seen at a preemption
    int          went_back;      // progress decreased after a resume
    uint32_t     mode;           // SAFE_CONFIGURATION when it was preempted
    uint32_t     modes_seen;     // bit m set: preempted at least once in mode m
    int          armed;          // fault armed by the host
    int          dmr_rec;        // DMR_REC seen while it was running (DCLS/LOCKSTEP rollback)
} task_stat_t;

typedef struct {
    uint64_t min, max, sum, n;
} stat_t;

static task_stat_t tstat[EROS_NTASKS]; // Task stats structure
static const char mode_letter[4] = { 'S', 'T', 'D', 'L' };

#define STAT_ALL 4
static stat_t lat[5];   // host cycles
static stat_t hdl[5];   // EROS cycles (handler)

static void stat_add(stat_t *s, uint32_t mode, uint64_t v)
{
    for (int k = 0; k < 2; k++) {
        stat_t *t = &s[k ? STAT_ALL : mode];
        if (t->n == 0 || v < t->min) t->min = v;
        if (v > t->max) t->max = v;
        t->sum += v;
        t->n++;
    }
}

static void stat_print(const char *title, const stat_t *s)
{
    printf("%s\n\r", title);
    for (int m = 0; m <= STAT_ALL; m++) {
        if (s[m].n == 0)
            continue;
        printf("  %-4s min %4u  avg %4u  max %4u  (%u samples)\n\r",
               m == STAT_ALL ? "all" : (char[]){ mode_letter[m], 0 },
               (uint32_t)s[m].min, (uint32_t)(s[m].sum / s[m].n), (uint32_t)s[m].max,
               (uint32_t)s[m].n);
    }
}

static inline uint64_t get_cycles(void)
{
    uint64_t c;
    asm volatile("csrr %0, mcycle" : "=r"(c));
    return c;
}

// -----------------------------------------------------------------------------
// EROS control
// -----------------------------------------------------------------------------

static void dump_eros_regs(void)
{
    printf("  START=0x%x END_SW=0x%x EXT_DBG=0x%x STATUS=0x%x INTC=0x%x\n\r",
           START, END_SW_ROUTINE, EXTERNAL_DEBUG_REQ, EROS_STATUS, INTERRUPT_CONTROLLER);
    printf("  ENTRY=0x%08x CTX=0x%08x COPY=0x%08x SP=0x%08x PREEMPT=0x%x\n\r",
           ENTRY_ADDRESS, PREEMPTIVE_CONTEXT_ADDR, SAFE_COPY_ADDRESS,
           INITIAL_STACK_ADDR, PREEMPTIVE_CTRL_STATUS);
}

static void eros_reset(void)
{
    START                  = 0x0;
    SAFE_CONFIGURATION     = 0x0;
    PREEMPTIVE_CTRL_STATUS = 0x0;

    for (int i = 0; i < EROS_SIGNATURE_WORDS; i++)
        EROS_SIG(i) = 0x0;

    for (int i = 0; i < EROS_NTASKS; i++)
        EROS_INJ(i) = 0x0;

    DMR_MASK    = 0x5;
    MASTER_CORE = 0x1;
}

static void dispatch(int i)
{
    const eros_task_t *t = &tasks[i];

    PREEMPTIVE_CONTEXT_ADDR = t->preempt_ctx;
    SAFE_COPY_ADDRESS       = t->safe_copy;
    SAFE_CONFIGURATION      = tstat[i].state == T_NEW ? 0x0 : tstat[i].mode;

    if (tstat[i].state == T_NEW) {
        ENTRY_ADDRESS          = t->entry;
        PREEMPTIVE_CTRL_STATUS = PREEMPT_START_TASK;
    } else {
        INITIAL_STACK_ADDR     = t->initial_sp;  /* fixed by its linker script */
        PREEMPTIVE_CTRL_STATUS = PREEMPT_CONTINUE_TASK;
    }

    // EROS idle (first dispatch, or the previous task ended): a rising edge
    // on START is needed, END_SW_ROUTINE must be cleared before.
    if (START == 0x0) {
        END_SW_ROUTINE       = 0x0;
        INTERRUPT_CONTROLLER = 0x0;
        START                = 0x1;
    }

    tstat[i].slices++;
}

static int preempt(int i)
{
    uint32_t ctx = tasks[i].preempt_ctx;
    PREEMPTIVE_CONTEXT_ADDR = ctx;

    PREEMPT_TS_ENTRY(ctx) = 0;
    PREEMPT_TS_END(ctx)   = 0;

    uint64_t t0 = get_cycles();
    PREEMPTIVE_CTRL_STATUS = PREEMPT_TRIGGER;

    for (;;) {
        if (PREEMPTIVE_CTRL_STATUS == PREEMPT_READY) {
            uint64_t t1 = get_cycles();
            uint32_t mode = SAFE_CONFIGURATION & 0x3;
            stat_add(lat, mode, t1 - t0);

            // Handler time measured by EROS itself, in EROS cycles
            uint32_t ts_entry = PREEMPT_TS_ENTRY(ctx);
            uint32_t ts_end   = PREEMPT_TS_END(ctx);
            if (ts_end != 0) {
                stat_add(hdl, mode, (uint32_t)(ts_end - ts_entry));
            }
            return 1;
        }
        if (END_SW_ROUTINE)
            return 0;
        if (get_cycles() - t0 > PREEMPT_TIMEOUT)
            return -1;
    }
}

static void task_ended(int i, int *done)
{
    tstat[i].state = T_DONE;
    (*done)++;
#if VERBOSE
    printf("[task%d] done      sig=0x%08x\n\r", i, EROS_SIG(i));
#endif
}

// -----------------------------------------------------------------------------
// Test
// -----------------------------------------------------------------------------

static int run_round_robin(void)
{
    int done = 0;
    uint32_t round;

    for (round = 0; done < EROS_NTASKS && round < MAX_ROUNDS; round++) {
        for (int i = 0; i < EROS_NTASKS; i++) {
            if (tstat[i].state == T_DONE)
                continue;

#if FAULT_INJECTION
            // Armed before the dispatch, the kernel takes it at its next iteration
            if (tstat[i].slices + 1 == FAULT_SLICE) {
                EROS_INJ(i) = EROS_INJ_ARMED;
                tstat[i].armed = 1;
            }
#endif

            dispatch(i);

#if !PREEMPT_LAST_TASK
            // Last task left: nothing to switch to, let it run to the end
            if (EROS_NTASKS - done == 1) {
                while (!END_SW_ROUTINE)
                    if (DMR_REC) tstat[i].dmr_rec = 1;
                task_ended(i, &done);
                continue;
            }
#endif

            uint64_t t0 = get_cycles();
            // condition to wait for the TIME_SLICE (10000 cycles) for each task after that check for the preemption
            while (get_cycles() - t0 < TIME_SLICE && !END_SW_ROUTINE)
                if (DMR_REC) tstat[i].dmr_rec = 1;   // recovery in progress, as in eros_aes_check.c

            if (END_SW_ROUTINE) {
                task_ended(i, &done);
                continue;
            }

            int r = preempt(i);
            if (r == 0) {
                task_ended(i, &done);
                continue;
            }
            if (r < 0) {
                printf("[task%d] ERROR: no PREEMPT_READY after %u cycles\n\r",
                       i, PREEMPT_TIMEOUT);
                dump_eros_regs();
                return -1;
            }

            tstat[i].state = T_PAUSED;
            tstat[i].preemptions++;
            tstat[i].mode = SAFE_CONFIGURATION & 0x3;
            tstat[i].modes_seen |= 1u << tstat[i].mode;

            uint32_t sig = EROS_SIG(i);
            uint32_t prog = TASK_SIG_STATE(sig) == TASK_SIG_RUNNING ? TASK_SIG_VALUE(sig) : 0;
            if (prog < tstat[i].progress)
                tstat[i].went_back = 1;
            tstat[i].progress = prog;
#if VERBOSE
            printf("[task%d] preempted #%u  mode=%c  progress=%u\n\r", i, tstat[i].preemptions,
                   mode_letter[tstat[i].mode], prog);
#endif
        }
    }

    if (done < EROS_NTASKS) {
        printf("ERROR: %d task(s) still running after %u rounds\n\r",
               EROS_NTASKS - done, round);
        return -1;
    }
    return 0;
}

static int check_results(void)
{
    int errors = 0, multi_preempted = 0;

    printf("\n\rtask kernel slices preempts modes  fault    result   expected  status\n\r");
    for (int i = 0; i < EROS_NTASKS; i++) {
        uint32_t sig    = EROS_SIG(i);
        uint32_t kernel = TASK_SIG_KERNEL(sig);
        uint32_t expect = TASK_SIG_VALUE(task_reference(kernel));

        int injected  = tstat[i].armed && EROS_INJ(i) == 0;
        int recovered = injected && (tstat[i].dmr_rec || tstat[i].went_back);
        const char *fault = !tstat[i].armed ? "-" :
                            !injected       ? "ARMED" :
                            recovered       ? "inj+rec" : "inj";

        const char *res = "PASS";
        if (TASK_SIG_STATE(sig) != TASK_SIG_DONE)  res = "FAIL not done";
        else if (kernel >= TASK_NKERNELS)            res = "FAIL bad kernel";
        else if (TASK_SIG_VALUE(sig) != expect)      res = "FAIL result";
        else if (tstat[i].armed && !injected)          res = "FAIL not injected";
        else if (tstat[i].went_back && !injected)      res = "FAIL restarted";

        if (res[0] == 'F')
            errors++;
        if (tstat[i].preemptions >= 2)
            multi_preempted++;

        // modes the task was preempted in, e.g. "ST" = in SINGLE and in TCLS
        char modes[5] = "-   ";
        for (int m = 0, n = 0; m < 4; m++)
            if (tstat[i].modes_seen & (1u << m))
                modes[n++] = mode_letter[m];

        printf("%4d %6u %6u %8u  %s  %-7s  0x%06x 0x%06x  %s\n\r",
               i, kernel, tstat[i].slices, tstat[i].preemptions, modes, fault,
               TASK_SIG_VALUE(sig), expect, res);
    }

    printf("\n\r");
    if (lat[STAT_ALL].n)
        stat_print("preempt latency (host cycles), per mode:", lat);
    if (hdl[STAT_ALL].n)
        stat_print("preempt handler (EROS cycles), per mode:", hdl);
    else if (lat[STAT_ALL].n)
        printf("WARNING: no EROS timestamps, build the tasks with PREEMPT_TIMING 1\n\r");

    if (multi_preempted == 0)
        printf("WARNING: no task was preempted twice, lower TIME_SLICE or raise TASK*_N\n\r");

    return errors;
}

int main(void)
{
    printf("\n\r=====================================\n\r");
    printf("  EROS ROUND-ROBIN PREEMPTION TEST\n\r");
    printf("  %d tasks, Time Slice %u host cycles\n\r", EROS_NTASKS, TIME_SLICE);
    printf("=====================================\n\r");

    eros_reset();

    uint64_t t0 = get_cycles();
    int r = run_round_robin();
    uint64_t total = get_cycles() - t0;

    int errors = check_results();

    printf("\n\rtotal %u host cycles\n\r", (uint32_t)total);
    if (r == 0 && errors == 0)
        printf("RESULT: PASS\n\r");
    else
        printf("RESULT: FAIL (%d task error(s)%s)\n\r", errors, r ? ", scheduler error" : "");

    return (r == 0 && errors == 0) ? 0 : 1;
}
