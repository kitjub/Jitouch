#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "JTEdgeVolumeScrubPolicy.h"

static int assertions;
static double testTimestamp;

static void Assert(bool condition, const char *message) {
    assertions++;
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

static JTEdgeVolumeScrubResult UpdateAt(JTEdgeVolumeScrubPolicy *policy,
                                        int count,
                                        int firstID,
                                        int secondID,
                                        float leftX,
                                        float rightX,
                                        float averageY,
                                        double timestamp,
                                        bool leftEnabled,
                                        bool rightEnabled) {
    return JTEdgeVolumeScrubPolicyUpdate(
        policy, count, firstID, secondID, leftX, rightX, averageY, timestamp,
        leftEnabled, rightEnabled);
}

static JTEdgeVolumeScrubResult Update(JTEdgeVolumeScrubPolicy *policy,
                                      int count,
                                      int firstID,
                                      int secondID,
                                      float leftX,
                                      float rightX,
                                      float averageY,
                                      bool leftEnabled,
                                      bool rightEnabled) {
    testTimestamp += 0.01;
    return UpdateAt(policy, count, firstID, secondID, leftX, rightX,
                    averageY, testTimestamp, leftEnabled, rightEnabled);
}

int main(void) {
    JTEdgeVolumeScrubPolicy policy =
        JT_EDGE_VOLUME_SCRUB_POLICY_INITIALIZER;
    JTEdgeVolumeScrubResult result;

    result = Update(&policy, 2, 9, 4, 0.68f, 0.95f, 0.50f, false, true);
    Assert(result.began, "a fresh right-edge pair begins a scrub");
    Assert(result.side == JTEdgeVolumeScrubSideRight,
           "the right edge is reported");
    Assert(JTEdgeVolumeScrubPolicyIsActive(&policy),
           "the active flag is externally visible");
    Assert(result.volumeSteps == 0, "activation never changes volume");

    result = Update(&policy, 2, 4, 9, 0.68f, 0.95f, 0.52f, false, true);
    Assert(result.volumeSteps == 0, "motion below the threshold is ignored");
    JTEdgeVolumeScrubPolicyRequestCancel(&policy);
    Assert(!JTEdgeVolumeScrubPolicyIsActive(&policy),
           "cross-thread cancellation clears shared ownership immediately");
    result = Update(&policy, 2, 4, 9, 0.68f, 0.95f, 0.52f, false, true);
    Assert(!result.began && result.volumeSteps == 0,
           "cancellation blocks re-entry until contacts lift");
    Update(&policy, 0, -1, -1, 0, 0, 0, false, true);
    result = Update(&policy, 2, 9, 4, 0.68f, 0.95f, 0.50f, false, true);
    Assert(result.began, "a fresh sequence can begin after cancellation");
    result = Update(&policy, 2, 4, 9, 0.68f, 0.95f, 0.52f, false, true);
    Assert(result.volumeSteps == 0, "fresh motion starts below threshold");
    result = Update(&policy, 2, 4, 9, 0.68f, 0.95f, 0.54f, false, true);
    Assert(result.volumeSteps == 1, "accumulated upward motion raises volume");
    result = Update(&policy, 2, 4, 9, 0.68f, 0.95f, 0.47f, false, true);
    Assert(result.volumeSteps == -2, "downward motion lowers volume");

    result = Update(&policy, 1, 4, -1, 0.95f, 0.95f, 0.47f, false, true);
    Assert(result.ended, "partial release ends the scrub");
    Assert(!JTEdgeVolumeScrubPolicyIsActive(&policy),
           "partial release clears the shared active flag");
    result = Update(&policy, 2, 4, 11, 0.70f, 0.96f, 0.47f, false, true);
    Assert(!result.began, "a second finger cannot re-arm before full release");
    Update(&policy, 0, -1, -1, 0, 0, 0, false, true);
    result = Update(&policy, 2, 4, 11, 0.70f, 0.96f, 0.47f, false, true);
    Assert(result.began, "full release permits a later scrub");

    result = Update(&policy, 2, 4, 12, 0.70f, 0.96f, 0.60f, false, true);
    Assert(result.ended, "contact replacement ends the active scrub");
    Assert(result.volumeSteps == 0,
           "contact replacement cannot create a volume jump");
    Update(&policy, 0, -1, -1, 0, 0, 0, false, true);

    result = Update(&policy, 2, 1, 2, 0.05f, 0.30f, 0.50f, true, false);
    Assert(result.began && result.side == JTEdgeVolumeScrubSideLeft,
           "a same-side left-edge pair is recognized");
    result = Update(&policy, 2, 1, 2, 0.05f, 0.30f, 1.0f, true, false);
    Assert(result.volumeSteps == 4, "one frame is capped at four steps");
    result = Update(&policy, 2, 1, 2, 0.05f, 0.30f, 1.0f, true, false);
    Assert(result.volumeSteps == 0, "a jump leaves no stationary backlog");
    Update(&policy, 0, -1, -1, 0, 0, 0, true, false);

    result = Update(&policy, 1, 1, -1, 0.90f, 0.90f, 0.50f, false, true);
    Assert(!result.began, "the first accepted contact does not poison arming");
    result = Update(&policy, 2, 1, 2, 0.58f, 0.87f, 0.50f, false, true);
    Assert(result.began,
           "the relaxed right-edge zone accepts a natural two-finger posture");
    Update(&policy, 0, -1, -1, 0, 0, 0, false, true);

    result = UpdateAt(&policy, 2, 1, 2, 0.40f, 0.60f, 0.50f,
                      10.0, true, true);
    Assert(!result.began, "an initially unsettled pair waits briefly");
    result = UpdateAt(&policy, 2, 1, 2, 0.05f, 0.30f, 0.50f,
                      10.12, true, true);
    Assert(result.began,
           "a pair may settle into the edge during the short arming grace");
    UpdateAt(&policy, 0, -1, -1, 0, 0, 0, 10.13, true, true);

    result = UpdateAt(&policy, 2, 1, 2, 0.40f, 0.60f, 0.50f,
                      11.0, true, true);
    Assert(!result.began, "a normal central scroll does not activate");
    result = UpdateAt(&policy, 2, 1, 2, 0.40f, 0.60f, 0.50f,
                      11.20, true, true);
    Assert(!result.began, "the brief arming window expires centrally");
    result = UpdateAt(&policy, 2, 1, 2, 0.05f, 0.30f, 0.50f,
                      11.21, true, true);
    Assert(!result.began,
           "an established central scroll cannot drift into volume control");
    Update(&policy, 0, -1, -1, 0, 0, 0, true, true);

    result = Update(&policy, 2, 1, 2, 0.05f, 0.95f, 0.50f, true, true);
    Assert(!result.began, "contacts spanning both edges are rejected");
    Update(&policy, 0, -1, -1, 0, 0, 0, true, true);

    result = Update(&policy, 3, 1, 2, 0.70f, 0.95f, 0.50f, false, true);
    Assert(!result.began, "three contacts never begin volume control");
    result = Update(&policy, 2, 1, 2, 0.70f, 0.95f, 0.50f, false, true);
    Assert(!result.began, "three-to-two remains blocked until all lift");
    Update(&policy, 0, -1, -1, 0, 0, 0, false, true);

    result = Update(&policy, 2, 1, 2, 0.70f, 0.95f, 0.50f, false, false);
    Assert(!result.began, "disabled sides never activate");
    Update(&policy, 0, -1, -1, 0, 0, 0, false, false);

    result = Update(&policy, 2, 1, 2, NAN, 0.95f, 0.50f, false, true);
    Assert(!result.began, "invalid geometry is fail-closed");
    Assert(!JTEdgeVolumeScrubPolicyIsActive(NULL),
           "a null policy is never active");
    result = Update(NULL, 2, 1, 2, 0.70f, 0.95f, 0.50f, false, true);
    Assert(!result.began && result.volumeSteps == 0,
           "a null policy update is harmless");

    printf("edge volume scrub policy tests passed (%d assertions)\n",
           assertions);
    return 0;
}
