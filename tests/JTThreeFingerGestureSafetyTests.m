#import <Foundation/Foundation.h>

#import "JTThreeFingerGestureSafety.h"

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
        for (NSString *gesture in @[
            @"Three-Finger Tap",
            @"Two-Fix Index-Double-Tap",
            @"Two-Fix Middle-Double-Tap",
            @"Two-Fix Ring-Double-Tap",
        ]) {
            Assert(JTThreeFingerGestureIsPassiveWithNativeDrag(gesture),
                   [NSString stringWithFormat:@"%@ stays passive", gesture]);
            Assert(!JTThreeFingerGestureConflictsWithNativeDrag(gesture),
                   [NSString stringWithFormat:@"%@ is allowed", gesture]);
        }

        for (NSString *gesture in @[
            @"One-Fix Two-Slide-Up", @"One-Fix Two-Slide-Down",
            @"One-Fix-Press Two-Slide-Up", @"One-Fix-Press Two-Slide-Down",
            @"Two-Fix One-Slide-Up", @"Two-Fix One-Slide-Down",
            @"Two-Fix One-Slide-Left", @"Two-Fix One-Slide-Right",
            @"Three-Finger Pinch-In", @"Three-Finger Pinch-Out",
            @"Three-Swipe-Up", @"Three-Swipe-Down",
            @"Three-Swipe-Left", @"Three-Swipe-Right",
            @"Three-Finger Click",
        ]) {
            Assert(JTThreeFingerGestureConflictsWithNativeDrag(gesture),
                   [NSString stringWithFormat:@"%@ is blocked", gesture]);
            Assert(!JTThreeFingerGestureIsPassiveWithNativeDrag(gesture),
                   [NSString stringWithFormat:@"%@ is not passive", gesture]);
        }

        for (NSString *gesture in @[
            @"One-Fix Left-Tap", @"Four-Finger Tap", @"Four-Swipe-Down",
            @"Pinky-To-Index", @"Index-To-Pinky", @"All Unassigned Gestures",
        ]) {
            Assert(JTThreeFingerGestureSafetyClassForGesture(gesture) ==
                       JTThreeFingerGestureSafetyClassUnrelated,
                   [NSString stringWithFormat:@"%@ remains unrelated", gesture]);
        }

        NSLog(@"PASS: %lu three-finger gesture safety assertions",
              (unsigned long)assertions);
    }
    return 0;
}
