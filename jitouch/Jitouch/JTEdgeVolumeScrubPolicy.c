#include "JTEdgeVolumeScrubPolicy.h"

#include <math.h>
#include <stddef.h>

/* One contact must touch the outer 14%, while its partner remains on the same
 * half of the trackpad. Both must arrive as the same fresh two-contact sequence.
 */
static const float kOuterEdge = 0.14f;
static const float kSameSideInnerLimit = 0.45f;
static const double kContactStabilizationSeconds = 0.18;
static const float kVolumeStepDistance = 0.03f;
static const int kMaximumStepsPerFrame = 4;

static JTEdgeVolumeScrubResult EmptyResult(void) {
    JTEdgeVolumeScrubResult result = {
        false, false, JTEdgeVolumeScrubSideNone, 0
    };
    return result;
}

static void StoreContactIDs(JTEdgeVolumeScrubPolicy *policy,
                            int firstContactID,
                            int secondContactID) {
    if (firstContactID <= secondContactID) {
        policy->firstContactID = firstContactID;
        policy->secondContactID = secondContactID;
    } else {
        policy->firstContactID = secondContactID;
        policy->secondContactID = firstContactID;
    }
}

static bool ContactIDsMatch(const JTEdgeVolumeScrubPolicy *policy,
                            int firstContactID,
                            int secondContactID) {
    if (firstContactID > secondContactID) {
        int temporary = firstContactID;
        firstContactID = secondContactID;
        secondContactID = temporary;
    }
    return policy->firstContactID == firstContactID &&
           policy->secondContactID == secondContactID;
}

static JTEdgeVolumeScrubSide StartingSide(float leftmostX,
                                          float rightmostX,
                                          bool leftEnabled,
                                          bool rightEnabled) {
    bool onLeft = leftEnabled && leftmostX <= kOuterEdge &&
                  rightmostX <= kSameSideInnerLimit;
    bool onRight = rightEnabled && rightmostX >= 1.0f - kOuterEdge &&
                   leftmostX >= 1.0f - kSameSideInnerLimit;
    if (onLeft == onRight) {
        return JTEdgeVolumeScrubSideNone;
    }
    return onLeft ? JTEdgeVolumeScrubSideLeft
                  : JTEdgeVolumeScrubSideRight;
}

void JTEdgeVolumeScrubPolicyReset(JTEdgeVolumeScrubPolicy *policy) {
    if (policy == NULL) return;
    atomic_store_explicit(&policy->active, false, memory_order_release);
    atomic_store_explicit(&policy->cancelRequested, false,
                          memory_order_release);
    policy->blockedUntilAllContactsLift = false;
    policy->arming = false;
    policy->side = JTEdgeVolumeScrubSideNone;
    policy->firstContactID = -1;
    policy->secondContactID = -1;
    policy->lastAverageY = 0.0f;
    policy->accumulatedY = 0.0f;
    policy->armingStartedAt = 0.0;
}

void JTEdgeVolumeScrubPolicyRequestCancel(
    JTEdgeVolumeScrubPolicy *policy) {
    if (policy == NULL) return;
    atomic_store_explicit(&policy->active, false, memory_order_release);
    atomic_store_explicit(&policy->cancelRequested, true,
                          memory_order_release);
}

bool JTEdgeVolumeScrubPolicyIsActive(
    const JTEdgeVolumeScrubPolicy *policy) {
    if (policy == NULL) return false;
    return atomic_load_explicit(&policy->active, memory_order_acquire);
}

JTEdgeVolumeScrubResult JTEdgeVolumeScrubPolicyUpdate(
    JTEdgeVolumeScrubPolicy *policy,
    int contactCount,
    int firstContactID,
    int secondContactID,
    float leftmostX,
    float rightmostX,
    float averageY,
    double timestamp,
    bool leftEnabled,
    bool rightEnabled) {
    JTEdgeVolumeScrubResult result = EmptyResult();
    if (policy == NULL) return result;

    bool wasActive = JTEdgeVolumeScrubPolicyIsActive(policy);
    bool cancellationRequested = atomic_exchange_explicit(
        &policy->cancelRequested, false, memory_order_acq_rel);
    if (cancellationRequested) {
        result.ended = wasActive;
        policy->blockedUntilAllContactsLift = contactCount > 0;
        policy->arming = false;
        policy->side = JTEdgeVolumeScrubSideNone;
        policy->firstContactID = -1;
        policy->secondContactID = -1;
        policy->lastAverageY = 0.0f;
        policy->accumulatedY = 0.0f;
        policy->armingStartedAt = 0.0;
        if (contactCount > 0) return result;
    }
    if (contactCount <= 0) {
        result.ended = wasActive;
        JTEdgeVolumeScrubPolicyReset(policy);
        return result;
    }

    if (contactCount != 2) {
        if (wasActive) {
            atomic_store_explicit(&policy->active, false,
                                  memory_order_release);
            result.ended = true;
        }
        if (contactCount >= 3 || wasActive || policy->arming) {
            policy->blockedUntilAllContactsLift = true;
        }
        policy->arming = false;
        return result;
    }

    if (policy->blockedUntilAllContactsLift) return result;

    if (!isfinite(leftmostX) || !isfinite(rightmostX) ||
        !isfinite(averageY) || !isfinite(timestamp) ||
        firstContactID < 0 || secondContactID < 0 ||
        firstContactID == secondContactID) {
        if (wasActive) result.ended = true;
        atomic_store_explicit(&policy->active, false, memory_order_release);
        policy->arming = false;
        policy->blockedUntilAllContactsLift = true;
        return result;
    }

    if (!wasActive) {
        if (!policy->arming) {
            StoreContactIDs(policy, firstContactID, secondContactID);
            policy->arming = true;
            policy->armingStartedAt = timestamp;
        } else if (!ContactIDsMatch(policy, firstContactID, secondContactID)) {
            policy->arming = false;
            policy->blockedUntilAllContactsLift = true;
            return result;
        }

        JTEdgeVolumeScrubSide side = StartingSide(
            leftmostX, rightmostX, leftEnabled, rightEnabled);
        if (side == JTEdgeVolumeScrubSideNone) {
            double elapsed = timestamp - policy->armingStartedAt;
            if (elapsed < 0.0 || elapsed > kContactStabilizationSeconds) {
                /* A normal scroll may not drift into volume control later. */
                policy->arming = false;
                policy->blockedUntilAllContactsLift = true;
            }
            return result;
        }
        policy->side = side;
        policy->arming = false;
        policy->lastAverageY = averageY;
        policy->accumulatedY = 0.0f;
        atomic_store_explicit(&policy->active, true, memory_order_release);
        result.began = true;
        result.side = side;
        return result;
    }

    bool sideStillEnabled =
        (policy->side == JTEdgeVolumeScrubSideLeft && leftEnabled) ||
        (policy->side == JTEdgeVolumeScrubSideRight && rightEnabled);
    if (!sideStillEnabled ||
        !ContactIDsMatch(policy, firstContactID, secondContactID)) {
        atomic_store_explicit(&policy->active, false, memory_order_release);
        policy->blockedUntilAllContactsLift = true;
        result.ended = true;
        return result;
    }

    float delta = averageY - policy->lastAverageY;
    policy->lastAverageY = averageY;
    policy->accumulatedY += delta;
    float maximumAccumulation =
        kVolumeStepDistance * (float)kMaximumStepsPerFrame;
    if (policy->accumulatedY > maximumAccumulation) {
        policy->accumulatedY = maximumAccumulation;
    } else if (policy->accumulatedY < -maximumAccumulation) {
        policy->accumulatedY = -maximumAccumulation;
    }

    float magnitude = fabsf(policy->accumulatedY);
    int steps = (int)floorf(magnitude / kVolumeStepDistance + 0.0001f);
    if (steps > kMaximumStepsPerFrame) steps = kMaximumStepsPerFrame;
    if (steps > 0) {
        result.volumeSteps = policy->accumulatedY > 0.0f ? steps : -steps;
        policy->accumulatedY -=
            (float)result.volumeSteps * kVolumeStepDistance;
        if (fabsf(policy->accumulatedY) < 0.000001f) {
            policy->accumulatedY = 0.0f;
        }
    }
    result.side = policy->side;
    return result;
}
