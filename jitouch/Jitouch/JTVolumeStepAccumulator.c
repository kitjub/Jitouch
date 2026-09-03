#include "JTVolumeStepAccumulator.h"

#include <limits.h>
#include <stdint.h>

static int ClampPending(int64_t value) {
    if (value > JT_VOLUME_STEP_ACCUMULATOR_MAX_PENDING) {
        return JT_VOLUME_STEP_ACCUMULATOR_MAX_PENDING;
    }
    if (value < -JT_VOLUME_STEP_ACCUMULATOR_MAX_PENDING) {
        return -JT_VOLUME_STEP_ACCUMULATOR_MAX_PENDING;
    }
    return (int)value;
}

void JTVolumeStepAccumulatorAdd(JTVolumeStepAccumulator *accumulator,
                                int steps) {
    if (accumulator == NULL || steps == 0) return;

    int current = atomic_load_explicit(&accumulator->pendingSteps,
                                       memory_order_relaxed);
    for (;;) {
        int desired = ClampPending((int64_t)current + (int64_t)steps);
        if (atomic_compare_exchange_weak_explicit(
                &accumulator->pendingSteps, &current, desired,
                memory_order_release, memory_order_relaxed)) {
            return;
        }
    }
}

int JTVolumeStepAccumulatorTake(JTVolumeStepAccumulator *accumulator,
                                int maxMagnitude) {
    if (accumulator == NULL || maxMagnitude <= 0) return 0;

    int current = atomic_load_explicit(&accumulator->pendingSteps,
                                       memory_order_acquire);
    for (;;) {
        int taken = current;
        if (taken > maxMagnitude) taken = maxMagnitude;
        if (taken < -maxMagnitude) taken = -maxMagnitude;
        int desired = current - taken;
        if (atomic_compare_exchange_weak_explicit(
                &accumulator->pendingSteps, &current, desired,
                memory_order_acq_rel, memory_order_acquire)) {
            return taken;
        }
    }
}

int JTVolumeStepAccumulatorPending(
    const JTVolumeStepAccumulator *accumulator) {
    if (accumulator == NULL) return 0;
    return atomic_load_explicit(&accumulator->pendingSteps,
                                memory_order_acquire);
}

void JTVolumeStepAccumulatorClear(JTVolumeStepAccumulator *accumulator) {
    if (accumulator == NULL) return;
    atomic_store_explicit(&accumulator->pendingSteps, 0, memory_order_release);
}
