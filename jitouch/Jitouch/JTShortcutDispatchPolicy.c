#include "JTShortcutDispatchPolicy.h"

#define JT_TAB_KEY_CODE ((CGKeyCode)48)

JTShortcutFocusPolicy JTShortcutFocusPolicyForChord(
    CGKeyCode keyCode,
    CGEventFlags modifierFlags) {
    const CGEventFlags relevantFlags =
        kCGEventFlagMaskShift |
        kCGEventFlagMaskControl |
        kCGEventFlagMaskAlternate |
        kCGEventFlagMaskCommand;
    const CGEventFlags chordFlags = modifierFlags & relevantFlags;
    const CGEventFlags forwardAppSwitch = kCGEventFlagMaskCommand;
    const CGEventFlags reverseAppSwitch =
        kCGEventFlagMaskCommand | kCGEventFlagMaskShift;

    if (keyCode == JT_TAB_KEY_CODE &&
        (chordFlags == forwardAppSwitch ||
         chordFlags == reverseAppSwitch)) {
        return JTShortcutFocusPolicyPreserveFrontmostApp;
    }
    return JTShortcutFocusPolicyActivatePointerTarget;
}
