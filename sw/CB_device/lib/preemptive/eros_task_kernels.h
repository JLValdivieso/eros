// Copyright 2026 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Jonathan Valdivieso (jonathan.lvaldivieso@upm.es)
//
// Workloads of the preemption test (sw/applications/task0..7), shared by the
// EROS tasks and the host (sw/host/eros_preempt_rr.c): the host runs the same
// kernels with progress = 0 to compute the expected result of every task.
//
// Only uint32_t arithmetic, so the results are identical on EROS (RV32) and
// on the host (RV64). All the state lives in registers and on the stack, so a
// wrong context save/restore changes the result.
//
// Signature word of task i (EROS_SIGNATURE_ADDRESS + 4*i):
//   [31:28] state   0x1 running, 0xD done
//   [27:24] kernel  which kernel the task runs (0..7)
//   [23:0]  running: iterations completed, done: result & 0xFFFFFF

#ifndef _EROS_TASK_KERNELS_H_
#define _EROS_TASK_KERNELS_H_

#include <stdint.h>

#define TASK_SIG_RUNNING       0x10000000u
#define TASK_SIG_DONE          0xD0000000u
#define TASK_SIG_TAG(st, k)    ((st) | ((uint32_t)(k) << 24))
#define TASK_SIG_STATE(v)      ((v) & 0xF0000000u)
#define TASK_SIG_KERNEL(v)     (((v) >> 24) & 0xFu)
#define TASK_SIG_VALUE(v)      ((v) & 0x00FFFFFFu)

#define TASK_NKERNELS          8

// Iterations of each kernel, tune them so that every task needs several
// time slices of the host (SLICE_CYCLES in eros_preempt_rr.c)
#define TASK0_N    60000u      // sum of squares
#define TASK1_N    60000u      // fibonacci mod 2^32
#define TASK2_N    60000u      // galois LFSR
#define TASK3_N    8000u       // bitwise CRC32 (8 steps per byte)
#define TASK4_N    4000u       // collatz steps of 1..N
#define TASK5_N    20000u      // primes below N
#define TASK6_N    60000u      // xorshift32
#define TASK7_N    40u         // bubble sort of 64 words on the stack


#define EROS_INJ_ADDRESS       0x0307B580u
#define EROS_INJ(i)            (*(volatile uint32_t *)(uintptr_t)(EROS_INJ_ADDRESS + 4u * (i)))
#define EROS_INJ_ARMED         1u
#define EROS_CORE_ID           (*(volatile uint32_t *)0x03040000u)  // CPU private reg, not compared

// Progress report, compiled out when progress == 0 (host reference run)
#define TASK_PROGRESS(i) do {                                               \
        if (progress) {                                                     \
            uint32_t v_ = tag | ((i) & 0x00FFFFFFu);                        \
            if (EROS_INJ(TASK_SIG_KERNEL(tag)) == EROS_INJ_ARMED) {         \
                EROS_INJ(TASK_SIG_KERNEL(tag)) = 0;                         \
                v_ += EROS_CORE_ID >> 2;                                    \
            }                                                               \
            *progress = v_;                                                 \
        }                                                                   \
    } while (0)

static inline uint32_t task_kernel0(volatile uint32_t *progress, uint32_t tag)
{
    uint32_t s = 0;
    for (uint32_t i = 1; i <= TASK0_N; i++) {
        s += i * i;
        TASK_PROGRESS(i);
    }
    return s;
}

static inline uint32_t task_kernel1(volatile uint32_t *progress, uint32_t tag)
{
    uint32_t a = 0, b = 1;
    for (uint32_t i = 1; i <= TASK1_N; i++) {
        uint32_t t = a + b;
        a = b;
        b = t;
        TASK_PROGRESS(i);
    }
    return b;
}

static inline uint32_t task_kernel2(volatile uint32_t *progress, uint32_t tag)
{
    uint32_t s = 0xACE1ACE1u;
    for (uint32_t i = 1; i <= TASK2_N; i++) {
        s = (s & 1u) ? (s >> 1) ^ 0x80200003u : s >> 1;
        TASK_PROGRESS(i);
    }
    return s;
}

static inline uint32_t task_kernel3(volatile uint32_t *progress, uint32_t tag)
{
    uint32_t crc = 0xFFFFFFFFu;
    for (uint32_t i = 1; i <= TASK3_N; i++) {
        crc ^= (i * 7u + 3u) & 0xFFu;
        for (uint32_t b = 0; b < 8; b++)
            crc = (crc & 1u) ? (crc >> 1) ^ 0xEDB88320u : crc >> 1;
        TASK_PROGRESS(i);
    }
    return ~crc;
}

static inline uint32_t task_kernel4(volatile uint32_t *progress, uint32_t tag)
{
    uint32_t steps = 0;
    for (uint32_t i = 1; i <= TASK4_N; i++) {
        uint32_t x = i;
        while (x != 1u) {
            x = (x & 1u) ? 3u * x + 1u : x >> 1;
            steps++;
        }
        TASK_PROGRESS(i);
    }
    return steps;
}

static inline uint32_t task_kernel5(volatile uint32_t *progress, uint32_t tag)
{
    uint32_t count = 1;     // 2
    for (uint32_t x = 3; x < TASK5_N; x += 2) {
        uint32_t prime = 1;
        for (uint32_t d = 3; d * d <= x; d += 2) {
            if (x % d == 0u) {
                prime = 0;
                break;
            }
        }
        count += prime;
        TASK_PROGRESS(x);
    }
    return count;
}

static inline uint32_t task_kernel6(volatile uint32_t *progress, uint32_t tag)
{
    uint32_t x = 2463534242u, sum = 0;
    for (uint32_t i = 1; i <= TASK6_N; i++) {
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        sum += x;
        TASK_PROGRESS(i);
    }
    return sum;
}

static inline uint32_t task_kernel7(volatile uint32_t *progress, uint32_t tag)
{
    volatile uint32_t arr[64];   // volatile: keep the array on the stack
    uint32_t check = 0;
    for (uint32_t rep = 1; rep <= TASK7_N; rep++) {
        uint32_t x = rep * 2654435761u;
        for (uint32_t i = 0; i < 64; i++) {
            x ^= x << 13;
            x ^= x >> 17;
            x ^= x << 5;
            arr[i] = x;
        }
        for (uint32_t i = 0; i < 63; i++) {
            for (uint32_t j = 0; j < 63 - i; j++) {
                uint32_t a = arr[j], b = arr[j + 1];
                if (a > b) {
                    arr[j] = b;
                    arr[j + 1] = a;
                }
            }
        }
        for (uint32_t i = 0; i < 64; i++)
            check = check * 31u + arr[i];
        TASK_PROGRESS(rep);
    }
    return check;
}

// Expected result of a kernel, used by the host
static inline uint32_t task_reference(uint32_t kernel)
{
    switch (kernel) {
        case 0: return task_kernel0(0, 0);
        case 1: return task_kernel1(0, 0);
        case 2: return task_kernel2(0, 0);
        case 3: return task_kernel3(0, 0);
        case 4: return task_kernel4(0, 0);
        case 5: return task_kernel5(0, 0);
        case 6: return task_kernel6(0, 0);
        case 7: return task_kernel7(0, 0);
        default: return 0;
    }
}

#endif
