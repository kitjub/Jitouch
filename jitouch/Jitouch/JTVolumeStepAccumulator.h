#ifndef JTVolumeStepAccumulator_h
#define JTVolumeStepAccumulator_h

#include <stdbool.h>
#include <stdatomic.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * A tiny lock-free pressure valve between the multitouch callback and AppKit's
 * main queue. Opposite directions cancel and pending work is saturated, so a
 * burst of touch frames cannot create an unbounded queue of media-key events.
 */
typedef struct {
    atomic_int pendingSteps;
} JTVolumeStepAccumulator;

#define JT_VOLUME_STEP_ACCUMULATOR_INITIALIZER { ATOMIC_VAR_INIT(0) }
#define JT_VOLUME_STEP_ACCUMULATOR_MAX_PENDING 8

void JTVolumeStepAccumulatorAdd(JTVolumeStepAccumulator *accumulator,
                                int steps);

/* Removes at most maxMagnitude steps while preserving their sign. */
int JTVolumeStepAccumulatorTake(JTVolumeStepAccumulator *accumulator,
                                int maxMagnitude);

int JTVolumeStepAccumulatorPending(
    const JTVolumeStepAccumulator *accumulator);

void JTVolumeStepAccumulatorClear(JTVolumeStepAccumulator *accumulator);

#ifdef __cplusplus
}
#endif

#endif /* JTVolumeStepAccumulator_h */
