// Copyright 2025 CEI UPM
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// Jonathan Lopez-Valdivieso (jonathan.lvaldivieso@upm.es)
//
// AES128-ECB executed under dual-core lockstep (DCLS) on the EROS safe island.
// Encrypts one NIST SP 800-38A KAT block inside the protected region, with a
// checkpoint that defines the rollback point on a DCLS comparison error.
// The result is published in a signature block that Cheshire reads externally.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "csr.h"
#include "csr_registers.h"
#include "CB_Safety.h"      // Safe_Activate / Safe_Stop / Store_Checkpoint + modes

// ECB only for this demo
#define CBC 0
#define CTR 0
#define ECB 1
#include "aes.h"

// Signature block read by Cheshire (SRAM Bank 0: 0x0306_0000 - 0x0306_7FFF)
#define SIGNATURE ((volatile uint32_t *)0x0306A000)

int main(int argc, char *argv[])
{

    // NIST SP 800-38A AES128-ECB known-answer test vector.
    // key/in/out are LOCALS -> they live on the stack, so they are captured by
    // the snapshot that Store_Checkpoint() copies (sp .. INITIAL_STACK_ADDR).
    uint8_t key[16] = { 0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6,
                        0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c };
    uint8_t in[16]  = { 0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96,
                        0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a };
    uint8_t out[16] = { 0x3a, 0xd7, 0x7b, 0xb4, 0x0d, 0x7a, 0x36, 0x60,
                        0xa8, 0x9e, 0xca, 0xf3, 0x24, 0x66, 0xef, 0x97 };

    struct AES_ctx ctx;

    SIGNATURE[0] = 0xDEADBEEF;   // main reached

    Safe_Activate(DCLS_MODE); //Enter Safe mode (TCLS_MODE DCLS_MODE LOCKSTEP_MODE)

    AES_init_ctx(&ctx, key);     // key expansion (round keys stored in 'ctx', stack)

    Store_Checkpoint();

    AES_ECB_encrypt(&ctx, in);   // <-- fault injection window

    Safe_Stop(MASTER_CORE2);     // back to single-core, master = core 0
    // -------- End of critical region --------

    // Correctness oracle: compare against the known NIST ciphertext.
    int ok = (0 == memcmp((const char *)out, (const char *)in, 16));

    // Dump the ciphertext into the signature block (memcpy avoids alignment /
    // strict-aliasing issues when reading the uint8_t[] as words).
    uint32_t w0, w1, w2, w3;
    memcpy(&w0, in +  0, 4);
    memcpy(&w1, in +  4, 4);
    memcpy(&w2, in +  8, 4);
    memcpy(&w3, in + 12, 4);

    SIGNATURE[1] = (uint32_t)ok;                  // 1 = KAT correct, 0 = failure
    SIGNATURE[2] = w0;
    SIGNATURE[3] = w1;
    SIGNATURE[4] = w2;
    SIGNATURE[5] = w3;
    SIGNATURE[6] = ok ? 0xCAFEBABE : 0xDEAD0BAD;  // computation completed

    return 0;
}