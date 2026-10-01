#ifndef JTTapClickFilter_h
#define JTTapClickFilter_h

#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * With macOS three-finger dragging on, every touch of a Two-Fix double tap
 * (or a stationary three-finger tap) reaches apps as a left click, which
 * activates whatever window is under the pointer. While a tap gesture is
 * armed, the filter holds the mouse-down: a drag releases it so native
 * dragging still works, and a mouse-up with no drag drops both.
 *
 * Arm is called from the multitouch thread; Handle and Reset run on the
 * event-tap (main) thread.
 */
typedef struct {
    atomic_uint_fast64_t armedUntilNanos;
    bool holding;
} JTTapClickFilter;

#define JT_TAP_CLICK_FILTER_INITIALIZER { ATOMIC_VAR_INIT(0), false }

/* macOS can deliver a tap's click just after the contact lifts. */
#define JT_TAP_CLICK_FILTER_GRACE_NANOS UINT64_C(250000000)

typedef enum {
    JTTapClickEventLeftDown,
    JTTapClickEventLeftDragged,
    JTTapClickEventLeftUp,
} JTTapClickEvent;

typedef enum {
    /* Deliver the event normally (and discard any stale held mouse-down). */
    JTTapClickDecisionPass,
    /* Keep a copy of this mouse-down and swallow it for now. */
    JTTapClickDecisionHold,
    /* A drag started: post the held mouse-down, then this event. */
    JTTapClickDecisionReleaseHeldThenPass,
    /* A tap ended without moving: swallow this mouse-up and the held down. */
    JTTapClickDecisionDropHeld,
} JTTapClickDecision;

/* Keeps the filter armed until the grace period after nowNanos. */
void JTTapClickFilterArm(JTTapClickFilter *filter, uint64_t nowNanos);

void JTTapClickFilterReset(JTTapClickFilter *filter);

JTTapClickDecision JTTapClickFilterHandle(JTTapClickFilter *filter,
                                          JTTapClickEvent event,
                                          uint64_t nowNanos);

#ifdef __cplusplus
}
#endif

#endif /* JTTapClickFilter_h */
