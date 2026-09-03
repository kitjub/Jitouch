#import <Cocoa/Cocoa.h>

#import "JTShortcutRecorderField.h"

static NSUInteger assertions;

static void Assert(BOOL condition, NSString *message) {
    assertions++;
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        JTShortcutRecorderField *field =
            [[JTShortcutRecorderField alloc] initWithFrame:NSZeroRect];
        Assert(!field.hasRecordedShortcut, @"new recorder has no shortcut");
        Assert(field.stringValue.length == 0, @"new recorder is visually empty");
        Assert([field.placeholderString containsString:@"press a shortcut"],
               @"new recorder explains how to record");

        [field setModifierFlags:0 keyCode:0];
        Assert(field.hasRecordedShortcut, @"loaded key code is a real shortcut");
        Assert([field.stringValue isEqualToString:@"A"],
               @"key code zero displays A only when actually loaded");

        [field clearShortcut];
        Assert(!field.hasRecordedShortcut, @"clearing removes recorded state");
        Assert(field.stringValue.length == 0, @"clearing removes misleading A");

        __block NSUInteger recordings = 0;
        field.recordingHandler = ^(JTShortcutRecorderField *sender) {
            Assert(sender == field, @"recording callback identifies its field");
            recordings++;
        };

        [field setModifierFlags:kCGEventFlagMaskCommand keyCode:48];
        Assert(recordings == 0,
               @"loading an existing shortcut does not imply user intent");

        NSEvent *recordedEvent =
            [NSEvent keyEventWithType:NSEventTypeKeyDown
                             location:NSZeroPoint
                        modifierFlags:NSEventModifierFlagCommand
                            timestamp:0
                         windowNumber:0
                              context:nil
                           characters:@"\t"
          charactersIgnoringModifiers:@"\t"
                            isARepeat:NO
                              keyCode:48];
        [field keyDown:recordedEvent];
        Assert(recordings == 1,
               @"recording a new shortcut announces the user's intent once");
        Assert(field.hasRecordedShortcut,
               @"recording callback leaves the shortcut available for saving");

        NSLog(@"PASS: %lu shortcut-recorder assertions", (unsigned long)assertions);
    }
    return 0;
}
