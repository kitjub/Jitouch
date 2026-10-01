// Stands in for the gesture engine so settings tests never touch real input.
#import "JTEngineController.h"

NSString *const JTEngineStateDidChangeNotification = @"JTEngineStateDidChangeNotification";

@implementation JTEngineController
- (BOOL)isRunning { return YES; }
- (BOOL)accessibilityGranted { return YES; }
- (BOOL)inputMonitoringGranted { return YES; }
- (void)start {}
- (void)retryAfterPermissionChange {}
- (void)reload {}
- (void)stop {}
@end
