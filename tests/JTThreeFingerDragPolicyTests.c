#include <stdio.h>
#include <stdlib.h>

#include "JTThreeFingerDragPolicy.h"

static unsigned int assertions;

static void Assert(bool condition, const char *message) {
    assertions++;
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

int main(void) {
    JTThreeFingerDragPolicy policy =
        JT_THREE_FINGER_DRAG_POLICY_INITIALIZER;

    Assert(!JTThreeFingerDragPolicyIsPassThroughActive(&policy),
           "a new policy is inactive");
    Assert(!JTThreeFingerDragPolicyUpdate(&policy, false, 3),
           "three contacts do not pass through when compatibility is disabled");
    Assert(!JTThreeFingerDragPolicyIsPassThroughActive(&policy),
           "disabled compatibility leaves the policy reset");

    Assert(!JTThreeFingerDragPolicyUpdate(&policy, true, 1),
           "one contact does not start native pass-through");
    Assert(!JTThreeFingerDragPolicyUpdate(&policy, true, 2),
           "two contacts do not start native pass-through");
    Assert(JTThreeFingerDragPolicyUpdate(&policy, true, 3),
           "exactly three contacts start native pass-through");
    Assert(JTThreeFingerDragPolicyUpdate(&policy, true, 2),
           "a finger-lift transition stays in the native drag sequence");
    Assert(JTThreeFingerDragPolicyUpdate(&policy, true, 1),
           "the native sequence remains active until every finger lifts");
    Assert(!JTThreeFingerDragPolicyUpdate(&policy, true, 0),
           "zero contacts ends native pass-through");

    Assert(JTThreeFingerDragPolicyUpdate(&policy, true, 3),
           "a later three-contact sequence can start");
    Assert(!JTThreeFingerDragPolicyUpdate(&policy, true, 4),
           "four contacts immediately return control to Jitouch");
    Assert(!JTThreeFingerDragPolicyUpdate(&policy, true, 3),
           "a four-to-three release does not start native pass-through");
    Assert(!JTThreeFingerDragPolicyUpdate(&policy, true, 2),
           "a four-finger sequence stays reserved through release");
    Assert(!JTThreeFingerDragPolicyUpdate(&policy, true, 0),
           "lifting every finger clears the four-finger reservation");
    Assert(JTThreeFingerDragPolicyUpdate(&policy, true, 3),
           "native pass-through works after the four-finger sequence ends");

    Assert(!JTThreeFingerDragPolicyUpdate(&policy, false, 3),
           "turning compatibility off resets an active sequence");
    Assert(!JTThreeFingerDragPolicyUpdate(&policy, true, 5),
           "five contacts are reserved for Jitouch");
    Assert(!JTThreeFingerDragPolicyUpdate(&policy, true, 3),
           "five-to-three remains reserved until all contacts lift");
    JTThreeFingerDragPolicyReset(&policy);
    Assert(!JTThreeFingerDragPolicyIsPassThroughActive(&policy),
           "an explicit reset clears pass-through");

    Assert(!JTThreeFingerDragPolicyUpdate(NULL, true, 3),
           "a missing policy fails safely");
    Assert(!JTThreeFingerDragPolicyIsPassThroughActive(NULL),
           "a missing policy is never active");

    printf("PASS: %u three-finger-drag policy assertions\n", assertions);
    return 0;
}
