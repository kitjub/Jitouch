#ifndef JTPreviousWindowPolicy_h
#define JTPreviousWindowPolicy_h

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * One on-screen window as reported by CGWindowListCopyWindowInfo. The window
 * server lists windows front to back, which is the most-recently-used order
 * Windows-style Alt-Tab needs: unlike Command-Tab, it treats two windows of
 * the same application as separate destinations.
 */
typedef struct {
    uint32_t windowID;
    pid_t ownerPID;
    int layer;
    double alpha;
    double width;
    double height;
} JTWindowCandidate;

#define JT_PREVIOUS_WINDOW_MIN_EXTENT 40.0

/* Normal, visible, user-sized windows that do not belong to Jitouch. */
int JTWindowCandidateIsSwitchable(const JTWindowCandidate *window,
                                  pid_t selfPID);

/*
 * Writes indices of switch destinations into outIndices, best first, and
 * returns how many were written. The focused window is never a destination.
 * When focusedWindowID is 0 (focus unknown), the frontmost switchable window
 * is assumed to be the current one. Callers try destinations in order so a
 * window that cannot be activated falls through to the next most recent one.
 */
size_t JTPreviousWindowOrderCandidates(const JTWindowCandidate *windows,
                                       size_t count,
                                       uint32_t focusedWindowID,
                                       pid_t selfPID,
                                       size_t *outIndices,
                                       size_t outCapacity);

#ifdef __cplusplus
}
#endif

#endif /* JTPreviousWindowPolicy_h */
