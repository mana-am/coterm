#include "TerminationWatchdogAtomic.h"

CoterminationWatchdogLatch CoterminationWatchdogLatchMake(void) {
    CoterminationWatchdogLatch latch;
    atomic_init(&latch.isArmed, false);
    return latch;
}

bool CoterminationWatchdogLatchClaim(CoterminationWatchdogLatch *latch) {
    bool expected = false;
    return atomic_compare_exchange_strong_explicit(
        &latch->isArmed,
        &expected,
        true,
        memory_order_acq_rel,
        memory_order_acquire
    );
}
