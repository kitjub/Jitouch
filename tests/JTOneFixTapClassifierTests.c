#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "JTOneFixTapClassifier.h"

static int assertions;

static void Assert(bool condition, const char *message) {
    assertions++;
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

static void Add(JTOneFixTapClassifier *classifier,
                float fixedX, float fixedY,
                float tapX, float tapY,
                bool leftHanded) {
    Assert(JTOneFixTapClassifierAddSample(
               classifier, 10, fixedX, fixedY, 20, tapX, tapY, leftHanded),
           "a matching contact pair is accepted");
}

int main(void) {
    JTOneFixTapClassifier classifier =
        JT_ONE_FIX_TAP_CLASSIFIER_INITIALIZER;

    Assert(JTOneFixTapClassifierBegin(&classifier, 10, 20),
           "a valid fixed/tapping pair begins");
    Add(&classifier, 0.65f, 0.55f, 0.35f, 0.45f, false);
    Add(&classifier, 0.64f, 0.56f, 0.36f, 0.44f, false);
    Assert(JTOneFixTapClassifierDirection(&classifier) ==
               JTOneFixTapDirectionLeft,
           "stable left geometry resolves left");

    JTOneFixTapClassifierReset(&classifier);
    Assert(JTOneFixTapClassifierBegin(&classifier, 10, 20),
           "reset permits a new pair");
    Add(&classifier, 0.35f, 0.45f, 0.65f, 0.55f, false);
    Add(&classifier, 0.34f, 0.46f, 0.66f, 0.54f, false);
    Assert(JTOneFixTapClassifierDirection(&classifier) ==
               JTOneFixTapDirectionRight,
           "stable right geometry resolves right");

    JTOneFixTapClassifierReset(&classifier);
    JTOneFixTapClassifierBegin(&classifier, 10, 20);
    Add(&classifier, 0.65f, 0.55f, 0.35f, 0.45f, false);
    Add(&classifier, 0.64f, 0.56f, 0.36f, 0.44f, false);
    Add(&classifier, 0.50f, 0.50f, 0.51f, 0.50f, false);
    Assert(JTOneFixTapClassifierDirection(&classifier) ==
               JTOneFixTapDirectionLeft,
           "one small contradictory sample cannot reverse consensus");

    JTOneFixTapClassifierReset(&classifier);
    JTOneFixTapClassifierBegin(&classifier, 10, 20);
    Add(&classifier, 0.50f, 0.50f, 0.49f, 0.51f, false);
    Add(&classifier, 0.50f, 0.50f, 0.51f, 0.49f, false);
    Assert(JTOneFixTapClassifierDirection(&classifier) ==
               JTOneFixTapDirectionAmbiguous,
           "boundary jitter is discarded instead of guessed");

    JTOneFixTapClassifierReset(&classifier);
    JTOneFixTapClassifierBegin(&classifier, 10, 20);
    Add(&classifier, 0.65f, 0.55f, 0.35f, 0.45f, true);
    Assert(JTOneFixTapClassifierDirection(&classifier) ==
               JTOneFixTapDirectionRight,
           "left-handed mapping preserves the historical axis reversal");

    JTOneFixTapClassifierReset(&classifier);
    JTOneFixTapClassifierBegin(&classifier, 10, 20);
    Assert(JTOneFixTapClassifierAddSample(
               &classifier, 20, 0.35f, 0.45f,
               10, 0.65f, 0.55f, false),
           "contact array reordering preserves identity");
    Assert(JTOneFixTapClassifierDirection(&classifier) ==
               JTOneFixTapDirectionLeft,
           "array reordering cannot reverse direction");

    JTOneFixTapClassifierReset(&classifier);
    JTOneFixTapClassifierBegin(&classifier, 10, 20);
    Assert(!JTOneFixTapClassifierAddSample(
               &classifier, 10, 0.65f, 0.55f,
               30, 0.35f, 0.45f, false),
           "contact replacement invalidates the sequence");
    Assert(JTOneFixTapClassifierDirection(&classifier) ==
               JTOneFixTapDirectionAmbiguous,
           "an invalid sequence cannot dispatch a direction");

    JTOneFixTapClassifierReset(&classifier);
    JTOneFixTapClassifierBegin(&classifier, 10, 20);
    Assert(!JTOneFixTapClassifierAddSample(
               &classifier, 10, NAN, 0.55f,
               20, 0.35f, 0.45f, false),
           "invalid geometry is fail-closed");
    Assert(JTOneFixTapClassifierDirection(NULL) ==
               JTOneFixTapDirectionAmbiguous,
           "a null classifier is ambiguous");
    Assert(!JTOneFixTapClassifierBegin(NULL, 10, 20),
           "a null classifier cannot begin");

    printf("one-fix tap classifier tests passed (%d assertions)\n",
           assertions);
    return 0;
}
