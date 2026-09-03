#ifndef JTEdgeVolumeScrubPolicy_h
#define JTEdgeVolumeScrubPolicy_h

#include <stdbool.h>
#include <stdatomic.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    JTEdgeVolumeScrubSideNone = 0,
    JTEdgeVolumeScrubSideLeft,
    JTEdgeVolumeScrubSideRight,
} JTEdgeVolumeScrubSide;

typedef struct {
    atomic_bool active;
    atomic_bool cancelRequested;
    bool blockedUntilAllContactsLift;
    bool arming;
    JTEdgeVolumeScrubSide side;
    int firstContactID;
    int secondContactID;
    float lastAverageY;
    float accumulatedY;
    double armingStartedAt;
} JTEdgeVolumeScrubPolicy;

#define JT_EDGE_VOLUME_SCRUB_POLICY_INITIALIZER \
    { ATOMIC_VAR_INIT(false), ATOMIC_VAR_INIT(false), false, false, \
      JTEdgeVolumeScrubSideNone, -1, -1, 0.0f, 0.0f, 0.0 }

typedef struct {
    bool began;
    bool ended;
    JTEdgeVolumeScrubSide side;
    /* Positive steps raise volume; negative steps lower it. */
    int volumeSteps;
} JTEdgeVolumeScrubResult;

/*
 * Recognizes a deliberate two-contact edge sequence without owning mouse
 * buttons. A fresh pair gets a short hardware-settling window to reach the same
 * edge. Any later transition from three or more contacts, contact replacement,
 * or partial release blocks a new scrub until every contact has lifted.
 */
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
    bool rightEnabled);

void JTEdgeVolumeScrubPolicyReset(JTEdgeVolumeScrubPolicy *policy);

/* Thread-safe cancellation for the CGEvent callback. The contact thread
 * consumes the request and owns the remaining mutable recognizer state.
 */
void JTEdgeVolumeScrubPolicyRequestCancel(
    JTEdgeVolumeScrubPolicy *policy);

bool JTEdgeVolumeScrubPolicyIsActive(
    const JTEdgeVolumeScrubPolicy *policy);

#ifdef __cplusplus
}
#endif

#endif /* JTEdgeVolumeScrubPolicy_h */
