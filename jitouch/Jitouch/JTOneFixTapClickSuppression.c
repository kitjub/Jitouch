#include "JTOneFixTapClickSuppression.h"

#include <limits.h>
#include <stddef.h>

static bool OwnsCurrentWindow(
    const JTOneFixTapClickSuppression *suppression,
    uint64_t nowNanos) {
    if (atomic_load_explicit(&suppression->contactOwned,
                             memory_order_acquire)) {
        return true;
    }
    uint64_t deadline = atomic_load_explicit(
        &suppression->suppressUntilNanos, memory_order_acquire);
    return deadline != 0 && nowNanos <= deadline;
}

static bool SuppressDown(JTOneFixTapClickSuppression *suppression,
                         atomic_bool *pair,
                         uint64_t nowNanos) {
    if (!OwnsCurrentWindow(suppression, nowNanos)) return false;
    atomic_store_explicit(pair, true, memory_order_release);
    return true;
}

static bool SuppressUp(JTOneFixTapClickSuppression *suppression,
                       atomic_bool *pair,
                       uint64_t nowNanos) {
    if (atomic_exchange_explicit(pair, false, memory_order_acq_rel)) {
        return true;
    }
    return OwnsCurrentWindow(suppression, nowNanos);
}

static bool SuppressDrag(JTOneFixTapClickSuppression *suppression,
                         const atomic_bool *pair,
                         uint64_t nowNanos) {
    return atomic_load_explicit(pair, memory_order_acquire) ||
           OwnsCurrentWindow(suppression, nowNanos);
}

void JTOneFixTapClickSuppressionReset(
    JTOneFixTapClickSuppression *suppression) {
    if (suppression == NULL) return;
    atomic_store_explicit(&suppression->contactOwned, false,
                          memory_order_release);
    atomic_store_explicit(&suppression->suppressUntilNanos, 0,
                          memory_order_release);
    atomic_store_explicit(&suppression->leftPairOwned, false,
                          memory_order_release);
    atomic_store_explicit(&suppression->rightPairOwned, false,
                          memory_order_release);
    atomic_store_explicit(&suppression->otherPairOwned, false,
                          memory_order_release);
}

void JTOneFixTapClickSuppressionBegin(
    JTOneFixTapClickSuppression *suppression) {
    if (suppression == NULL) return;
    atomic_store_explicit(&suppression->contactOwned, true,
                          memory_order_release);
}

void JTOneFixTapClickSuppressionEnd(
    JTOneFixTapClickSuppression *suppression,
    uint64_t nowNanos) {
    if (suppression == NULL) return;
    uint64_t deadline = UINT64_MAX - nowNanos <
                            JT_ONE_FIX_TAP_CLICK_GRACE_NANOS
        ? UINT64_MAX
        : nowNanos + JT_ONE_FIX_TAP_CLICK_GRACE_NANOS;
    atomic_store_explicit(&suppression->suppressUntilNanos, deadline,
                          memory_order_release);
    atomic_store_explicit(&suppression->contactOwned, false,
                          memory_order_release);
}

void JTOneFixTapClickSuppressionContactsLifted(
    JTOneFixTapClickSuppression *suppression,
    uint64_t nowNanos) {
    if (suppression == NULL) return;
    if (atomic_load_explicit(&suppression->contactOwned,
                             memory_order_acquire)) {
        JTOneFixTapClickSuppressionEnd(suppression, nowNanos);
    }
}

bool JTOneFixTapClickSuppressionShouldSuppress(
    JTOneFixTapClickSuppression *suppression,
    JTOneFixPointerEvent event,
    uint64_t nowNanos) {
    if (suppression == NULL) return false;
    switch (event) {
        case JTOneFixPointerEventLeftDown:
            return SuppressDown(suppression, &suppression->leftPairOwned,
                                nowNanos);
        case JTOneFixPointerEventLeftUp:
            return SuppressUp(suppression, &suppression->leftPairOwned,
                              nowNanos);
        case JTOneFixPointerEventLeftDragged:
            return SuppressDrag(suppression, &suppression->leftPairOwned,
                                nowNanos);
        case JTOneFixPointerEventRightDown:
            return SuppressDown(suppression, &suppression->rightPairOwned,
                                nowNanos);
        case JTOneFixPointerEventRightUp:
            return SuppressUp(suppression, &suppression->rightPairOwned,
                              nowNanos);
        case JTOneFixPointerEventRightDragged:
            return SuppressDrag(suppression, &suppression->rightPairOwned,
                                nowNanos);
        case JTOneFixPointerEventOtherDown:
            return SuppressDown(suppression, &suppression->otherPairOwned,
                                nowNanos);
        case JTOneFixPointerEventOtherUp:
            return SuppressUp(suppression, &suppression->otherPairOwned,
                              nowNanos);
        case JTOneFixPointerEventOtherDragged:
            return SuppressDrag(suppression, &suppression->otherPairOwned,
                                nowNanos);
        case JTOneFixPointerEventNone:
            return false;
    }
    return false;
}
