#ifndef COTERM_TERMINATION_WATCHDOG_ATOMIC_H
#define COTERM_TERMINATION_WATCHDOG_ATOMIC_H

#include <stdbool.h>
#include <stdatomic.h>

typedef struct {
    atomic_bool isArmed;
} CoterminationWatchdogLatch;

CoterminationWatchdogLatch CoterminationWatchdogLatchMake(void);
bool CoterminationWatchdogLatchClaim(CoterminationWatchdogLatch *latch);

#endif
