#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "JTTapClickFilter.h"

static int assertions;

static void Assert(bool condition, const char *message) {
    assertions++;
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

int main(void) {
    JTTapClickFilter filter = JT_TAP_CLICK_FILTER_INITIALIZER;
    const uint64_t now = UINT64_C(5000000000);
    const uint64_t grace = JT_TAP_CLICK_FILTER_GRACE_NANOS;

    Assert(JTTapClickFilterHandle(&filter, JTTapClickEventLeftDown, now) ==
               JTTapClickDecisionPass,
           "ordinary clicks pass while no tap gesture is armed");
    Assert(JTTapClickFilterHandle(&filter, JTTapClickEventLeftUp, now) ==
               JTTapClickDecisionPass,
           "its mouse-up passes too");

    JTTapClickFilterArm(&filter, now);
    Assert(JTTapClickFilterHandle(&filter, JTTapClickEventLeftDown, now + 1) ==
               JTTapClickDecisionHold,
           "an armed tap holds the mouse-down");
    Assert(JTTapClickFilterHandle(&filter, JTTapClickEventLeftUp, now + 2) ==
               JTTapClickDecisionDropHeld,
           "a tap that lifts without moving drops the click");
    Assert(JTTapClickFilterHandle(&filter, JTTapClickEventLeftUp, now + 3) ==
               JTTapClickDecisionPass,
           "only one mouse-up is swallowed per held down");

    Assert(JTTapClickFilterHandle(&filter, JTTapClickEventLeftDown, now + 4) ==
               JTTapClickDecisionHold,
           "the second touch of a double tap is held as well");
    Assert(JTTapClickFilterHandle(&filter, JTTapClickEventLeftDragged, now + 5) ==
               JTTapClickDecisionReleaseHeldThenPass,
           "a native three-finger drag releases the held mouse-down");
    Assert(JTTapClickFilterHandle(&filter, JTTapClickEventLeftDragged, now + 6) ==
               JTTapClickDecisionPass,
           "later drag events pass untouched");
    Assert(JTTapClickFilterHandle(&filter, JTTapClickEventLeftUp, now + 7) ==
               JTTapClickDecisionPass,
           "the drag's mouse-up is delivered");

    Assert(JTTapClickFilterHandle(&filter, JTTapClickEventLeftDown, now + grace - 1) ==
               JTTapClickDecisionHold,
           "a click macOS delivers just after the lift is still caught");
    JTTapClickFilterHandle(&filter, JTTapClickEventLeftUp, now + grace);
    Assert(JTTapClickFilterHandle(&filter, JTTapClickEventLeftDown, now + grace + 1) ==
               JTTapClickDecisionPass,
           "clicks pass once the grace period expires");
    JTTapClickFilterHandle(&filter, JTTapClickEventLeftUp, now + grace + 2);

    JTTapClickFilterArm(&filter, now);
    JTTapClickFilterHandle(&filter, JTTapClickEventLeftDown, now + 1);
    JTTapClickFilterReset(&filter);
    Assert(JTTapClickFilterHandle(&filter, JTTapClickEventLeftUp, now + 2) ==
               JTTapClickDecisionPass,
           "reset forgets the held click and disarms");
    Assert(JTTapClickFilterHandle(&filter, JTTapClickEventLeftDown, now + 3) ==
               JTTapClickDecisionPass,
           "reset disarms the filter");

    Assert(JTTapClickFilterHandle(NULL, JTTapClickEventLeftDown, now) ==
               JTTapClickDecisionPass,
           "a null filter never swallows input");
    JTTapClickFilterArm(NULL, now);
    JTTapClickFilterReset(NULL);

    printf("tap click filter tests passed (%d assertions)\n", assertions);
    return 0;
}
