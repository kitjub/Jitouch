#include "JTCommandDispatchPolicy.h"

#include <math.h>

bool JTCommandDispatchPolicyTryEnqueue(JTCommandDispatchPolicy *policy) {
    if (policy == NULL) return false;

    int current = atomic_load_explicit(&policy->pendingCount,
                                       memory_order_relaxed);
    for (;;) {
        if (current >= JT_COMMAND_DISPATCH_MAX_PENDING) return false;
        if (atomic_compare_exchange_weak_explicit(
                &policy->pendingCount, &current, current + 1,
                memory_order_acq_rel, memory_order_relaxed)) {
            return true;
        }
    }
}

bool JTCommandDispatchPolicyBeginExecution(JTCommandDispatchPolicy *policy,
                                           double ageSeconds) {
    if (policy == NULL) return false;

    int previous = atomic_fetch_sub_explicit(&policy->pendingCount, 1,
                                              memory_order_acq_rel);
    if (previous <= 0) {
        atomic_fetch_add_explicit(&policy->pendingCount, 1,
                                  memory_order_release);
        return false;
    }
    return isfinite(ageSeconds) && ageSeconds >= 0.0 &&
           ageSeconds <= JT_COMMAND_DISPATCH_MAX_AGE_SECONDS;
}

int JTCommandDispatchPolicyPending(const JTCommandDispatchPolicy *policy) {
    if (policy == NULL) return 0;
    return atomic_load_explicit(&policy->pendingCount, memory_order_acquire);
}
