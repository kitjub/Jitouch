#include <ApplicationServices/ApplicationServices.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include "JTShortcutDispatchPolicy.h"

static int assertions;

static void Assert(bool condition, const char *message) {
    assertions++;
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

int main(void) {
    Assert(JTShortcutFocusPolicyForChord(
               48, kCGEventFlagMaskCommand) ==
               JTShortcutFocusPolicyPreserveFrontmostApp,
           "Command-Tab preserves the app that defines MRU switching");
    Assert(JTShortcutFocusPolicyForChord(
               48, kCGEventFlagMaskCommand | kCGEventFlagMaskShift) ==
               JTShortcutFocusPolicyPreserveFrontmostApp,
           "Shift-Command-Tab preserves the app that defines reverse MRU switching");
    Assert(JTShortcutFocusPolicyForChord(
               48, kCGEventFlagMaskCommand | UINT64_C(0x13)) ==
               JTShortcutFocusPolicyPreserveFrontmostApp,
           "legacy non-modifier flag bits do not change app-switch semantics");

    Assert(JTShortcutFocusPolicyForChord(
               33, kCGEventFlagMaskCommand) ==
               JTShortcutFocusPolicyActivatePointerTarget,
           "Command-left-bracket keeps Jitouch pointer-target behavior");
    Assert(JTShortcutFocusPolicyForChord(
               21, kCGEventFlagMaskCommand | kCGEventFlagMaskShift |
                       kCGEventFlagMaskControl) ==
               JTShortcutFocusPolicyActivatePointerTarget,
           "Screenshot keeps the existing recorded-shortcut focus behavior");
    Assert(JTShortcutFocusPolicyForChord(
               48, kCGEventFlagMaskCommand | kCGEventFlagMaskAlternate) ==
               JTShortcutFocusPolicyActivatePointerTarget,
           "Option-Command-Tab is not mistaken for the app switcher chord");
    Assert(JTShortcutFocusPolicyForChord(
               48, kCGEventFlagMaskControl) ==
               JTShortcutFocusPolicyActivatePointerTarget,
           "Control-Tab remains an application shortcut");

    printf("shortcut dispatch policy tests passed (%d assertions)\n",
           assertions);
    return 0;
}
