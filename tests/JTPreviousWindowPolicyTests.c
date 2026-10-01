#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "JTPreviousWindowPolicy.h"

static int assertions;

static void Assert(bool condition, const char *message) {
    assertions++;
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

static JTWindowCandidate Window(uint32_t windowID, pid_t ownerPID) {
    JTWindowCandidate window = {windowID, ownerPID, 0, 1.0, 800.0, 600.0};
    return window;
}

#define SELF_PID 99
#define CHROME_PID 10
#define MESSAGES_PID 20

int main(void) {
    size_t order[8];
    size_t n;

    {
        /* Chrome 2 focused, Chrome 1 behind it, Messages already closed. */
        JTWindowCandidate windows[] = {
            Window(202, CHROME_PID),
            Window(201, CHROME_PID),
        };
        n = JTPreviousWindowOrderCandidates(windows, 2, 202, SELF_PID, order, 8);
        Assert(n == 1 && order[0] == 1,
               "a second window of the same app is a switch destination");
    }

    {
        /* Messages is behind both Chrome windows, so it must not win. */
        JTWindowCandidate windows[] = {
            Window(201, CHROME_PID),
            Window(202, CHROME_PID),
            Window(300, MESSAGES_PID),
        };
        n = JTPreviousWindowOrderCandidates(windows, 3, 201, SELF_PID, order, 8);
        Assert(n == 2 && order[0] == 1 && order[1] == 2,
               "destinations follow window-server MRU order, not app order");
    }

    {
        JTWindowCandidate windows[] = {
            Window(201, CHROME_PID),
            Window(202, CHROME_PID),
        };
        n = JTPreviousWindowOrderCandidates(windows, 2, 0, SELF_PID, order, 8);
        Assert(n == 1 && order[0] == 1,
               "unknown focus treats the frontmost window as current");
    }

    {
        /* Focus sits behind a non-activating window of another app. */
        JTWindowCandidate windows[] = {
            Window(300, MESSAGES_PID),
            Window(201, CHROME_PID),
            Window(202, CHROME_PID),
        };
        n = JTPreviousWindowOrderCandidates(windows, 3, 201, SELF_PID, order, 8);
        Assert(n == 2 && order[0] == 0 && order[1] == 2,
               "only the focused window is excluded when it is not frontmost");
    }

    {
        JTWindowCandidate menuBar = Window(1, MESSAGES_PID);
        menuBar.layer = 24;
        JTWindowCandidate invisible = Window(2, MESSAGES_PID);
        invisible.alpha = 0.0;
        JTWindowCandidate sliver = Window(3, MESSAGES_PID);
        sliver.height = 4.0;
        JTWindowCandidate jitouch = Window(4, SELF_PID);
        JTWindowCandidate windows[] = {
            menuBar, Window(201, CHROME_PID), invisible, sliver, jitouch,
            Window(202, CHROME_PID),
        };
        n = JTPreviousWindowOrderCandidates(windows, 6, 201, SELF_PID, order, 8);
        Assert(n == 1 && order[0] == 5,
               "overlays, invisible, tiny, and Jitouch windows are skipped");
        Assert(!JTWindowCandidateIsSwitchable(&jitouch, SELF_PID),
               "Jitouch never switches to its own windows");
        Assert(JTWindowCandidateIsSwitchable(&windows[1], SELF_PID),
               "a normal document window is switchable");
    }

    {
        JTWindowCandidate windows[] = {Window(201, CHROME_PID)};
        n = JTPreviousWindowOrderCandidates(windows, 1, 201, SELF_PID, order, 8);
        Assert(n == 0, "a lone window has no destination");
        n = JTPreviousWindowOrderCandidates(NULL, 0, 0, SELF_PID, order, 8);
        Assert(n == 0, "an empty window list has no destination");
    }

    {
        JTWindowCandidate windows[] = {
            Window(201, CHROME_PID),
            Window(202, CHROME_PID),
            Window(203, CHROME_PID),
            Window(204, CHROME_PID),
        };
        n = JTPreviousWindowOrderCandidates(windows, 4, 201, SELF_PID, order, 2);
        Assert(n == 2 && order[0] == 1 && order[1] == 2,
               "output is truncated to the caller's capacity");
    }

    printf("previous window policy tests passed (%d assertions)\n", assertions);
    return 0;
}
