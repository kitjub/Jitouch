#include "JTKeyboardEvent.h"

#include <stddef.h>

typedef struct {
    CGEventFlags flag;
    CGKeyCode keyCode;
} JTModifierKey;

/*
 * Left-side modifier virtual key codes from the macOS keyboard layout. Their
 * order is stable and the reverse order is used for release.
 */
static const JTModifierKey kModifierKeys[] = {
    { kCGEventFlagMaskControl, 59 },
    { kCGEventFlagMaskAlternate, 58 },
    { kCGEventFlagMaskShift, 56 },
    { kCGEventFlagMaskCommand, 55 },
};

CGEventFlags JTKeyboardEventModifierFlags(bool shiftDown,
                                          bool controlDown,
                                          bool optionDown,
                                          bool commandDown) {
    CGEventFlags flags = 0;
    if (shiftDown) flags |= kCGEventFlagMaskShift;
    if (controlDown) flags |= kCGEventFlagMaskControl;
    if (optionDown) flags |= kCGEventFlagMaskAlternate;
    if (commandDown) flags |= kCGEventFlagMaskCommand;
    return flags;
}

CGEventRef JTKeyboardEventCreate(CGKeyCode keyCode,
                                 bool keyDown,
                                 CGEventFlags flags) {
    CGEventRef event = CGEventCreateKeyboardEvent(NULL, keyCode, keyDown);
    if (event != NULL) CGEventSetFlags(event, flags);
    return event;
}

pid_t JTKeyboardEventResolvedTargetPID(JTKeyboardEventDelivery delivery,
                                       pid_t targetPID) {
    if (delivery == JTKeyboardEventDeliveryTargetApplication &&
        targetPID > 0) {
        return targetPID;
    }
    return 0;
}

size_t JTKeyboardEventBuildStrokePlan(
    CGKeyCode keyCode,
    CGEventFlags flags,
    JTKeyboardEventDelivery delivery,
    JTKeyboardEventStroke *strokes,
    size_t capacity) {
    size_t modifierCount = 0;
    if (delivery == JTKeyboardEventDeliveryUserSession) {
        for (size_t i = 0;
             i < sizeof(kModifierKeys) / sizeof(kModifierKeys[0]); i++) {
            if ((flags & kModifierKeys[i].flag) != 0) modifierCount++;
        }
    }

    size_t required = 2 + modifierCount * 2;
    if (strokes == NULL || capacity < required) return required;

    size_t count = 0;
    CGEventFlags activeFlags = 0;
    if (delivery == JTKeyboardEventDeliveryUserSession) {
        for (size_t i = 0;
             i < sizeof(kModifierKeys) / sizeof(kModifierKeys[0]); i++) {
            if ((flags & kModifierKeys[i].flag) == 0) continue;
            activeFlags |= kModifierKeys[i].flag;
            strokes[count++] = (JTKeyboardEventStroke) {
                kModifierKeys[i].keyCode, true, activeFlags
            };
        }
    } else {
        activeFlags = flags;
    }

    strokes[count++] = (JTKeyboardEventStroke) {
        keyCode, true, activeFlags
    };
    strokes[count++] = (JTKeyboardEventStroke) {
        keyCode, false, activeFlags
    };

    if (delivery == JTKeyboardEventDeliveryUserSession) {
        for (size_t i = sizeof(kModifierKeys) / sizeof(kModifierKeys[0]);
             i > 0; i--) {
            const JTModifierKey modifier = kModifierKeys[i - 1];
            if ((flags & modifier.flag) == 0) continue;
            activeFlags &= ~modifier.flag;
            strokes[count++] = (JTKeyboardEventStroke) {
                modifier.keyCode, false, activeFlags
            };
        }
    }

    return count;
}

void JTKeyboardEventPost(CGEventRef event,
                         JTKeyboardEventDelivery delivery,
                         pid_t targetPID) {
    if (event == NULL) return;
    pid_t resolvedPID =
        JTKeyboardEventResolvedTargetPID(delivery, targetPID);
    if (resolvedPID > 0) {
        CGEventPostToPid(resolvedPID, event);
    } else {
        CGEventPost(kCGSessionEventTap, event);
    }
}
