#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, JTThreeFingerGestureSafetyClass) {
    JTThreeFingerGestureSafetyClassUnrelated = 0,
    JTThreeFingerGestureSafetyClassPassiveTap,
    JTThreeFingerGestureSafetyClassMotionConflict,
    JTThreeFingerGestureSafetyClassClickConflict,
};

/// Classifies trackpad gestures by whether they can safely observe the same
/// contacts used by macOS native three-finger dragging. Passive gestures never
/// need to consume or rewrite pointer events; motion/click gestures do.
FOUNDATION_EXPORT JTThreeFingerGestureSafetyClass
JTThreeFingerGestureSafetyClassForGesture(NSString *gesture);

FOUNDATION_EXPORT BOOL
JTThreeFingerGestureConflictsWithNativeDrag(NSString *gesture);

FOUNDATION_EXPORT BOOL
JTThreeFingerGestureIsPassiveWithNativeDrag(NSString *gesture);

NS_ASSUME_NONNULL_END
