#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "JTVolumeStepAccumulator.h"

static int assertions;

static void Assert(bool condition, const char *message) {
    assertions++;
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

int main(void) {
    JTVolumeStepAccumulator accumulator =
        JT_VOLUME_STEP_ACCUMULATOR_INITIALIZER;

    Assert(JTVolumeStepAccumulatorPending(&accumulator) == 0,
           "a fresh accumulator is empty");
    JTVolumeStepAccumulatorAdd(&accumulator, 3);
    Assert(JTVolumeStepAccumulatorPending(&accumulator) == 3,
           "positive steps accumulate");
    JTVolumeStepAccumulatorAdd(&accumulator, -1);
    Assert(JTVolumeStepAccumulatorPending(&accumulator) == 2,
           "opposite directions cancel before dispatch");
    Assert(JTVolumeStepAccumulatorTake(&accumulator, 1) == 1,
           "a drain can take a bounded positive chunk");
    Assert(JTVolumeStepAccumulatorPending(&accumulator) == 1,
           "a bounded drain preserves the remainder");
    Assert(JTVolumeStepAccumulatorTake(&accumulator, 4) == 1,
           "a drain does not invent extra work");

    JTVolumeStepAccumulatorAdd(&accumulator, 1000);
    Assert(JTVolumeStepAccumulatorPending(&accumulator) == 8,
           "positive bursts saturate");
    Assert(JTVolumeStepAccumulatorTake(&accumulator, 4) == 4,
           "the first saturated chunk is bounded");
    Assert(JTVolumeStepAccumulatorTake(&accumulator, 4) == 4,
           "the saturated remainder drains separately");

    JTVolumeStepAccumulatorAdd(&accumulator, -1000);
    Assert(JTVolumeStepAccumulatorPending(&accumulator) == -8,
           "negative bursts saturate");
    Assert(JTVolumeStepAccumulatorTake(&accumulator, 3) == -3,
           "negative work drains with its sign");
    JTVolumeStepAccumulatorClear(&accumulator);
    Assert(JTVolumeStepAccumulatorPending(&accumulator) == 0,
           "clear removes queued work");

    JTVolumeStepAccumulatorAdd(NULL, 2);
    JTVolumeStepAccumulatorClear(NULL);
    Assert(JTVolumeStepAccumulatorTake(NULL, 2) == 0,
           "null operations are harmless");
    Assert(JTVolumeStepAccumulatorTake(&accumulator, 0) == 0,
           "an invalid drain bound does nothing");

    printf("volume step accumulator tests passed (%d assertions)\n",
           assertions);
    return 0;
}
