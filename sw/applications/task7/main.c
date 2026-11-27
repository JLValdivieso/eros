#include <stdint.h>
#include "CB_Safety.h"
#include "eros_tasks_addr.h"
#include "eros_task_kernels.h"

#define TASK_MODE  TCLS_MODE

// Slot of this image in the task layout, set by link_task<i>.ld
extern char __task_id[];

int main(int argc, char *argv[])
{
        uint32_t id = (uint32_t)(uintptr_t)__task_id;
        volatile uint32_t *sig = (volatile uint32_t *)EROS_SIGNATURE_ADDRESS + id;

        Safe_Activate(TASK_MODE);

        uint32_t result = task_kernel7(sig, TASK_SIG_TAG(TASK_SIG_RUNNING, 7));

        *sig = TASK_SIG_TAG(TASK_SIG_DONE, 7) | TASK_SIG_VALUE(result);

        // Back to SINGLE: core 0 is the master configured by the host and it
        // belongs to the DCLS pair (DMR_MASK 0x5)
        Safe_Stop(MASTER_CORE0);

        return 0;
}
