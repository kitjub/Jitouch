#include "JTTapClickFilter.h"

#include <stddef.h>

void JTTapClickFilterArm(JTTapClickFilter *filter, uint64_t nowNanos) {
    if (filter == NULL) return;
    uint64_t until = UINT64_MAX - nowNanos < JT_TAP_CLICK_FILTER_GRACE_NANOS
        ? UINT64_MAX
        : nowNanos + JT_TAP_CLICK_FILTER_GRACE_NANOS;
    atomic_store_explicit(&filter->armedUntilNanos, until, memory_order_release);
}

void JTTapClickFilterReset(JTTapClickFilter *filter) {
    if (filter == NULL) return;
    atomic_store_explicit(&filter->armedUntilNanos, 0, memory_order_release);
    filter->holding = false;
}

static bool IsArmed(const JTTapClickFilter *filter, uint64_t nowNanos) {
    uint64_t until = atomic_load_explicit(&filter->armedUntilNanos,
                                          memory_order_acquire);
    return until != 0 && nowNanos <= until;
}

JTTapClickDecision JTTapClickFilterHandle(JTTapClickFilter *filter,
                                          JTTapClickEvent event,
                                          uint64_t nowNanos) {
    if (filter == NULL) return JTTapClickDecisionPass;
    bool wasHolding = filter->holding;
    switch (event) {
        case JTTapClickEventLeftDown:
            filter->holding = IsArmed(filter, nowNanos);
            return filter->holding ? JTTapClickDecisionHold
                                   : JTTapClickDecisionPass;
        case JTTapClickEventLeftDragged:
            filter->holding = false;
            return wasHolding ? JTTapClickDecisionReleaseHeldThenPass
                              : JTTapClickDecisionPass;
        case JTTapClickEventLeftUp:
            filter->holding = false;
            return wasHolding ? JTTapClickDecisionDropHeld
                              : JTTapClickDecisionPass;
    }
    return JTTapClickDecisionPass;
}
