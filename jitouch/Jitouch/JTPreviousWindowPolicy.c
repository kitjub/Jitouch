#include "JTPreviousWindowPolicy.h"

int JTWindowCandidateIsSwitchable(const JTWindowCandidate *window,
                                  pid_t selfPID) {
    if (window == NULL || window->windowID == 0) {
        return 0;
    }
    /* Layer 0 holds document windows; menus, Dock, and overlays sit above. */
    if (window->layer != 0 || window->ownerPID == selfPID) {
        return 0;
    }
    if (window->alpha <= 0.0) {
        return 0;
    }
    return window->width >= JT_PREVIOUS_WINDOW_MIN_EXTENT &&
           window->height >= JT_PREVIOUS_WINDOW_MIN_EXTENT;
}

size_t JTPreviousWindowOrderCandidates(const JTWindowCandidate *windows,
                                       size_t count,
                                       uint32_t focusedWindowID,
                                       pid_t selfPID,
                                       size_t *outIndices,
                                       size_t outCapacity) {
    size_t written = 0;
    int skipFrontmost = focusedWindowID == 0;

    if (windows == NULL || outIndices == NULL) {
        return 0;
    }
    for (size_t i = 0; i < count && written < outCapacity; i++) {
        const JTWindowCandidate *window = &windows[i];
        if (!JTWindowCandidateIsSwitchable(window, selfPID)) {
            continue;
        }
        if (skipFrontmost) {
            skipFrontmost = 0;
            continue;
        }
        if (window->windowID == focusedWindowID) {
            continue;
        }
        outIndices[written++] = i;
    }
    return written;
}
