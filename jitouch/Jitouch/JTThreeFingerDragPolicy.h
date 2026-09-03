#ifndef JTThreeFingerDragPolicy_h
#define JTThreeFingerDragPolicy_h

#include <stdbool.h>
#include <stdatomic.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Tracks whether low-level mouse events belong to a native macOS
 * three-finger-drag sequence.  The active flag is atomic because multitouch
 * contacts and CGEvents can be delivered on different threads.
 *
 * Once four or more contacts appear, the sequence stays reserved for Jitouch
 * until every contact is lifted.  This prevents the 4 -> 3 release transition
 * from being mistaken for the start of a native three-finger drag.
 */
typedef struct {
    atomic_bool nativePassThroughActive;
    atomic_bool blockedUntilAllContactsLift;
} JTThreeFingerDragPolicy;

#define JT_THREE_FINGER_DRAG_POLICY_INITIALIZER \
    { ATOMIC_VAR_INIT(false), ATOMIC_VAR_INIT(false) }

void JTThreeFingerDragPolicyReset(JTThreeFingerDragPolicy *policy);

bool JTThreeFingerDragPolicyUpdate(JTThreeFingerDragPolicy *policy,
                                   bool compatibilityEnabled,
                                   int contactCount);

bool JTThreeFingerDragPolicyIsPassThroughActive(
    const JTThreeFingerDragPolicy *policy);

#ifdef __cplusplus
}
#endif

#endif /* JTThreeFingerDragPolicy_h */
