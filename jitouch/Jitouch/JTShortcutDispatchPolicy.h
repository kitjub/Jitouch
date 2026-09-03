#ifndef JTShortcutDispatchPolicy_h
#define JTShortcutDispatchPolicy_h

#include <ApplicationServices/ApplicationServices.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    /* Preserve Jitouch's long-standing focus-follows-pointer shortcut model. */
    JTShortcutFocusPolicyActivatePointerTarget = 0,

    /* Keep the current frontmost app because the chord uses it as input. */
    JTShortcutFocusPolicyPreserveFrontmostApp,
} JTShortcutFocusPolicy;

JTShortcutFocusPolicy JTShortcutFocusPolicyForChord(
    CGKeyCode keyCode,
    CGEventFlags modifierFlags);

#ifdef __cplusplus
}
#endif

#endif /* JTShortcutDispatchPolicy_h */
