#import <Foundation/Foundation.h>

extern NSString *const JTEngineStateDidChangeNotification;

/// Owns the legacy gesture engine for the lifetime of the modern, nib-free app.
///
/// This adapter deliberately replaces the lifecycle work that used to live in
/// JitouchAppDelegate.  The legacy app delegate and main.m must not be linked
/// into the modern target.
@interface JTEngineController : NSObject

@property(nonatomic, readonly, getter=isRunning) BOOL running;
@property(nonatomic, readonly) BOOL accessibilityGranted;
@property(nonatomic, readonly) BOOL inputMonitoringGranted;

- (void)start;
- (void)retryAfterPermissionChange;
- (void)reload;
- (void)stop;

@end
