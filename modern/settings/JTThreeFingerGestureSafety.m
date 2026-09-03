#import "JTThreeFingerGestureSafety.h"

JTThreeFingerGestureSafetyClass
JTThreeFingerGestureSafetyClassForGesture(NSString *gesture) {
    if (gesture.length == 0) return JTThreeFingerGestureSafetyClassUnrelated;

    static NSSet<NSString *> *passiveGestures;
    static NSSet<NSString *> *motionGestures;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        passiveGestures = [NSSet setWithArray:@[
            @"Three-Finger Tap",
            @"Two-Fix Index-Double-Tap",
            @"Two-Fix Middle-Double-Tap",
            @"Two-Fix Ring-Double-Tap",
        ]];
        motionGestures = [NSSet setWithArray:@[
            @"One-Fix Two-Slide-Up", @"One-Fix Two-Slide-Down",
            @"One-Fix-Press Two-Slide-Up", @"One-Fix-Press Two-Slide-Down",
            @"Two-Fix One-Slide-Up", @"Two-Fix One-Slide-Down",
            @"Two-Fix One-Slide-Left", @"Two-Fix One-Slide-Right",
            @"Three-Finger Pinch-In", @"Three-Finger Pinch-Out",
            @"Three-Swipe-Up", @"Three-Swipe-Down",
            @"Three-Swipe-Left", @"Three-Swipe-Right",
        ]];
    });

    if ([passiveGestures containsObject:gesture]) {
        return JTThreeFingerGestureSafetyClassPassiveTap;
    }
    if ([motionGestures containsObject:gesture]) {
        return JTThreeFingerGestureSafetyClassMotionConflict;
    }
    if ([gesture isEqualToString:@"Three-Finger Click"]) {
        return JTThreeFingerGestureSafetyClassClickConflict;
    }
    return JTThreeFingerGestureSafetyClassUnrelated;
}

BOOL JTThreeFingerGestureConflictsWithNativeDrag(NSString *gesture) {
    JTThreeFingerGestureSafetyClass safetyClass =
        JTThreeFingerGestureSafetyClassForGesture(gesture);
    return safetyClass == JTThreeFingerGestureSafetyClassMotionConflict ||
           safetyClass == JTThreeFingerGestureSafetyClassClickConflict;
}

BOOL JTThreeFingerGestureIsPassiveWithNativeDrag(NSString *gesture) {
    return JTThreeFingerGestureSafetyClassForGesture(gesture) ==
           JTThreeFingerGestureSafetyClassPassiveTap;
}
