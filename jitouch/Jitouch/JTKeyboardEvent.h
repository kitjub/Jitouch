#ifndef JTKeyboardEvent_h
#define JTKeyboardEvent_h

#include <ApplicationServices/ApplicationServices.h>
#include <stdbool.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    /*
     * Behaves like a physical keyboard event in the current user session.
     * This is required for user-recorded shortcuts because macOS may own the
     * shortcut globally (for example, Screenshot) before an app sees it.
     */
    JTKeyboardEventDeliveryUserSession = 0,

    /*
     * Delivers directly to the app resolved by the gesture engine. This keeps
     * built-in application commands deterministic when focus is changing.
     */
    JTKeyboardEventDeliveryTargetApplication,
} JTKeyboardEventDelivery;

typedef struct {
    CGKeyCode keyCode;
    bool keyDown;
    CGEventFlags flags;
} JTKeyboardEventStroke;

#define JT_KEYBOARD_EVENT_MAX_CHORD_STROKES 10

CGEventFlags JTKeyboardEventModifierFlags(bool shiftDown,
                                          bool controlDown,
                                          bool optionDown,
                                          bool commandDown);

CGEventRef JTKeyboardEventCreate(CGKeyCode keyCode,
                                 bool keyDown,
                                 CGEventFlags flags);

/*
 * Returns the PID used by JTKeyboardEventPost. Zero means session delivery.
 * Keeping this decision explicit prevents global shortcuts from accidentally
 * being narrowed to the application under the pointer.
 */
pid_t JTKeyboardEventResolvedTargetPID(JTKeyboardEventDelivery delivery,
                                       pid_t targetPID);

/*
 * Builds the complete physical-key lifecycle for a shortcut. Session delivery
 * includes modifier down/up strokes so system UI such as the app switcher
 * cannot be left waiting for a modifier release. Targeted application
 * delivery retains the compact flagged key pair that is deterministic for
 * commands sent directly to a PID.
 */
size_t JTKeyboardEventBuildStrokePlan(
    CGKeyCode keyCode,
    CGEventFlags flags,
    JTKeyboardEventDelivery delivery,
    JTKeyboardEventStroke *strokes,
    size_t capacity);

void JTKeyboardEventPost(CGEventRef event,
                         JTKeyboardEventDelivery delivery,
                         pid_t targetPID);

#ifdef __cplusplus
}
#endif

#endif /* JTKeyboardEvent_h */
