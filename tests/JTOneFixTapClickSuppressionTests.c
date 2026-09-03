#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "JTOneFixTapClickSuppression.h"

static int assertions;

static void Assert(bool condition, const char *message) {
    assertions++;
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

int main(void) {
    JTOneFixTapClickSuppression suppression =
        JT_ONE_FIX_TAP_CLICK_SUPPRESSION_INITIALIZER;
    uint64_t now = UINT64_C(1000000000);

    Assert(!JTOneFixTapClickSuppressionShouldSuppress(
               &suppression, JTOneFixPointerEventLeftDown, now),
           "ordinary clicks pass before gesture ownership");

    JTOneFixTapClickSuppressionBegin(&suppression);
    Assert(JTOneFixTapClickSuppressionShouldSuppress(
               &suppression, JTOneFixPointerEventLeftDown, now),
           "left down is consumed during One-Fix overlap");
    Assert(JTOneFixTapClickSuppressionShouldSuppress(
               &suppression, JTOneFixPointerEventLeftDragged, now),
           "a drag cannot leak after its down was consumed");
    JTOneFixTapClickSuppressionEnd(&suppression, now);
    Assert(JTOneFixTapClickSuppressionShouldSuppress(
               &suppression, JTOneFixPointerEventLeftUp,
               now + JT_ONE_FIX_TAP_CLICK_GRACE_NANOS + 1),
           "paired up is consumed even after grace expires");
    Assert(!JTOneFixTapClickSuppressionShouldSuppress(
               &suppression, JTOneFixPointerEventLeftUp,
               now + JT_ONE_FIX_TAP_CLICK_GRACE_NANOS + 1),
           "an unrelated later up is not consumed");

    JTOneFixTapClickSuppressionBegin(&suppression);
    JTOneFixTapClickSuppressionEnd(&suppression, now);
    Assert(JTOneFixTapClickSuppressionShouldSuppress(
               &suppression, JTOneFixPointerEventRightDown,
               now + JT_ONE_FIX_TAP_CLICK_GRACE_NANOS - 1),
           "delayed two-finger secondary click is consumed in grace");
    Assert(JTOneFixTapClickSuppressionShouldSuppress(
               &suppression, JTOneFixPointerEventRightUp,
               now + JT_ONE_FIX_TAP_CLICK_GRACE_NANOS + 5),
           "right-click ownership remains paired");
    Assert(!JTOneFixTapClickSuppressionShouldSuppress(
               &suppression, JTOneFixPointerEventRightDown,
               now + JT_ONE_FIX_TAP_CLICK_GRACE_NANOS + 5),
           "right clicks pass after grace");

    JTOneFixTapClickSuppressionBegin(&suppression);
    Assert(JTOneFixTapClickSuppressionShouldSuppress(
               &suppression, JTOneFixPointerEventOtherDown, now),
           "other-button down is also owned");
    Assert(JTOneFixTapClickSuppressionShouldSuppress(
               &suppression, JTOneFixPointerEventOtherUp, now),
           "other-button up stays paired");
    JTOneFixTapClickSuppressionReset(&suppression);
    Assert(!JTOneFixTapClickSuppressionShouldSuppress(
               &suppression, JTOneFixPointerEventLeftDown, now),
           "reset restores ordinary clicking");

    Assert(!JTOneFixTapClickSuppressionShouldSuppress(
               NULL, JTOneFixPointerEventLeftDown, now),
           "a null policy never consumes input");
    JTOneFixTapClickSuppressionBegin(NULL);
    JTOneFixTapClickSuppressionEnd(NULL, now);
    JTOneFixTapClickSuppressionReset(NULL);

    printf("one-fix click suppression tests passed (%d assertions)\n",
           assertions);
    return 0;
}
