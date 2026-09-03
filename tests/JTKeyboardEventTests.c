#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "JTKeyboardEvent.h"

static int assertions;

static void Assert(bool condition, const char *message) {
    assertions++;
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

int main(void) {
    CGEventFlags flags = JTKeyboardEventModifierFlags(
        true, true, false, true);
    Assert((flags & kCGEventFlagMaskShift) != 0,
           "shift is represented in event flags");
    Assert((flags & kCGEventFlagMaskControl) != 0,
           "control is represented in event flags");
    Assert((flags & kCGEventFlagMaskAlternate) == 0,
           "an unused option modifier stays clear");
    Assert((flags & kCGEventFlagMaskCommand) != 0,
           "command is represented in event flags");

    CGEventRef down = JTKeyboardEventCreate(48, true, flags);
    CGEventRef up = JTKeyboardEventCreate(48, false, flags);
    Assert(down != NULL && up != NULL, "keyboard events are created");
    Assert(CGEventGetType(down) == kCGEventKeyDown,
           "the down event has the correct type");
    Assert(CGEventGetType(up) == kCGEventKeyUp,
           "the up event has the correct type");
    Assert(CGEventGetIntegerValueField(down, kCGKeyboardEventKeycode) == 48,
           "the event preserves its key code");
    Assert((CGEventGetFlags(down) & flags) == flags,
           "the event preserves modifier flags");

    Assert(JTKeyboardEventResolvedTargetPID(
               JTKeyboardEventDeliveryTargetApplication, 1234) == 1234,
           "built-in app commands preserve their resolved target PID");
    Assert(JTKeyboardEventResolvedTargetPID(
               JTKeyboardEventDeliveryUserSession, 1234) == 0,
           "user shortcuts remain session-wide even when an app PID exists");
    Assert(JTKeyboardEventResolvedTargetPID(
               JTKeyboardEventDeliveryTargetApplication, 0) == 0,
           "an unresolved app safely falls back to session delivery");

    JTKeyboardEventStroke targeted[JT_KEYBOARD_EVENT_MAX_CHORD_STROKES];
    size_t targetedCount = JTKeyboardEventBuildStrokePlan(
        48, kCGEventFlagMaskCommand,
        JTKeyboardEventDeliveryTargetApplication, targeted,
        JT_KEYBOARD_EVENT_MAX_CHORD_STROKES);
    Assert(targetedCount == 2,
           "targeted app commands retain a compact key pair");
    Assert(targeted[0].keyDown && !targeted[1].keyDown,
           "targeted app key down and up remain paired");
    Assert(targeted[0].flags == kCGEventFlagMaskCommand &&
               targeted[1].flags == kCGEventFlagMaskCommand,
           "targeted app key pair carries its modifier flags");

    JTKeyboardEventStroke session[JT_KEYBOARD_EVENT_MAX_CHORD_STROKES];
    size_t sessionCount = JTKeyboardEventBuildStrokePlan(
        48, kCGEventFlagMaskCommand,
        JTKeyboardEventDeliveryUserSession, session,
        JT_KEYBOARD_EVENT_MAX_CHORD_STROKES);
    Assert(sessionCount == 4,
           "Command-Tab session delivery has a full four-stroke lifecycle");
    Assert(session[0].keyCode == 55 && session[0].keyDown &&
               session[0].flags == kCGEventFlagMaskCommand,
           "Command is pressed before Tab");
    Assert(session[1].keyCode == 48 && session[1].keyDown &&
               session[2].keyCode == 48 && !session[2].keyDown,
           "Tab down and up occur while Command is active");
    Assert(session[3].keyCode == 55 && !session[3].keyDown &&
               session[3].flags == 0,
           "Command is explicitly released after Tab");

    CGEventFlags screenshotFlags = JTKeyboardEventModifierFlags(
        true, true, false, true);
    size_t screenshotCount = JTKeyboardEventBuildStrokePlan(
        21, screenshotFlags, JTKeyboardEventDeliveryUserSession,
        session, JT_KEYBOARD_EVENT_MAX_CHORD_STROKES);
    Assert(screenshotCount == 8,
           "three-modifier Screenshot shortcut has a complete lifecycle");
    Assert(session[screenshotCount - 1].flags == 0,
           "every Screenshot modifier is released at the end");

    size_t required = JTKeyboardEventBuildStrokePlan(
        48, screenshotFlags, JTKeyboardEventDeliveryUserSession,
        NULL, 0);
    Assert(required == 8,
           "the planner reports required capacity without writing");

    JTKeyboardEventPost(NULL, JTKeyboardEventDeliveryUserSession, 0);
    JTKeyboardEventPost(NULL, JTKeyboardEventDeliveryTargetApplication, 1234);
    CFRelease(down);
    CFRelease(up);
    printf("keyboard event tests passed (%d assertions)\n", assertions);
    return 0;
}
