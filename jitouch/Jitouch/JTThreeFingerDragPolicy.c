#include "JTThreeFingerDragPolicy.h"

void JTThreeFingerDragPolicyReset(JTThreeFingerDragPolicy *policy) {
    if (policy == NULL) {
        return;
    }

    atomic_store_explicit(&policy->nativePassThroughActive, false,
                          memory_order_release);
    atomic_store_explicit(&policy->blockedUntilAllContactsLift, false,
                          memory_order_release);
}

bool JTThreeFingerDragPolicyUpdate(JTThreeFingerDragPolicy *policy,
                                   bool compatibilityEnabled,
                                   int contactCount) {
    if (policy == NULL) {
        return false;
    }

    if (!compatibilityEnabled || contactCount <= 0) {
        JTThreeFingerDragPolicyReset(policy);
        return false;
    }

    if (contactCount >= 4) {
        atomic_store_explicit(&policy->nativePassThroughActive, false,
                              memory_order_release);
        atomic_store_explicit(&policy->blockedUntilAllContactsLift, true,
                              memory_order_release);
        return false;
    }

    if (atomic_load_explicit(&policy->blockedUntilAllContactsLift,
                             memory_order_acquire)) {
        return false;
    }

    if (contactCount == 3) {
        atomic_store_explicit(&policy->nativePassThroughActive, true,
                              memory_order_release);
    }

    return JTThreeFingerDragPolicyIsPassThroughActive(policy);
}

bool JTThreeFingerDragPolicyIsPassThroughActive(
    const JTThreeFingerDragPolicy *policy) {
    if (policy == NULL) {
        return false;
    }

    return atomic_load_explicit(&policy->nativePassThroughActive,
                                memory_order_acquire);
}
