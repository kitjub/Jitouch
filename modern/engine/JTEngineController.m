#import "JTEngineController.h"

#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>

#import "CursorWindow.h"
#import "Gesture.h"
#import "Settings.h"

// Gesture.m imports these declarations from the old JitouchAppDelegate.h.  The
// modern executable does not link that delegate, so this lifecycle adapter owns
// their single definitions instead.
CursorWindow *cursorWindow = nil;
CGKeyCode keyMap[128];

static NSString *const JTLegacySettingsNotification = @"My Notification";
static NSString *const JTLegacySettingsObject = @"com.jitouch.Jitouch.PrefpaneTarget";
NSString *const JTEngineStateDidChangeNotification = @"JTEngineStateDidChangeNotification";

@interface JTEngineController () {
    Gesture *_gesture;
    BOOL _running;
    BOOL _accessibilityGranted;
    BOOL _inputMonitoringGranted;
}

- (void)legacySettingsDidChange:(NSNotification *)notification;
- (void)applySettingsDictionary:(NSDictionary *)newSettings;
- (void)workspaceDidWake:(NSNotification *)notification;
- (void)reloadOnMainThread;
- (BOOL)refreshPermissionsRequestingAccess:(BOOL)requestAccess;
- (void)postStateDidChange;

@end

@implementation JTEngineController

- (BOOL)isRunning {
    return _running;
}

- (BOOL)accessibilityGranted {
    return _accessibilityGranted;
}

- (BOOL)inputMonitoringGranted {
    return _inputMonitoringGranted;
}

- (BOOL)refreshPermissionsRequestingAccess:(BOOL)requestAccess {
    if (requestAccess) {
        NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
                                                              forKey:(id)kAXTrustedCheckOptionPrompt];
        _accessibilityGranted = AXIsProcessTrustedWithOptions((CFDictionaryRef)options);
    } else {
        _accessibilityGranted = AXIsProcessTrusted();
    }

    _inputMonitoringGranted = CGPreflightListenEventAccess();
    if (requestAccess && !_inputMonitoringGranted) {
        _inputMonitoringGranted = CGRequestListenEventAccess();
    }
    return _accessibilityGranted && _inputMonitoringGranted;
}

- (void)postStateDidChange {
    [[NSNotificationCenter defaultCenter] postNotificationName:JTEngineStateDidChangeNotification
                                                        object:self];
}

- (void)start {
    if (_running) {
        return;
    }

    NSAssert([NSThread isMainThread], @"The gesture engine must start on the main thread.");

    // Both services are required before MultitouchSupport and the session event
    // tap are initialized. On current macOS, starting first can leave a live UI
    // around an engine whose MTDeviceStart call was rejected by TCC.
    if (![self refreshPermissionsRequestingAccess:YES]) {
        [self postStateDidChange];
        return;
    }

    // Preserve the legacy keyboard-map global even though KeyUtility now keeps
    // its own layout map.  Identity values are the historical safe default.
    for (NSUInteger index = 0; index < sizeof(keyMap) / sizeof(keyMap[0]); index++) {
        keyMap[index] = (CGKeyCode)index;
    }

    [Settings loadSettings];
    // The old preference pane created the initial settings file.  The modern
    // app can run without that pane, so it must also own first-run defaults.
    // Never replace an existing domain: this path is only taken when no usable
    // settings dictionary was loaded.
    if (settings == nil || [settings count] == 0) {
        [Settings createDefaultPlist];
        [Settings loadSettings];
    }
    cursorWindow = [[CursorWindow alloc] init];
    _gesture = [[Gesture alloc] init];

    [[NSDistributedNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(legacySettingsDidChange:)
               name:JTLegacySettingsNotification
             object:JTLegacySettingsObject];
    [[[NSWorkspace sharedWorkspace] notificationCenter]
        addObserver:self
           selector:@selector(workspaceDidWake:)
               name:NSWorkspaceDidWakeNotification
             object:nil];

    _running = YES;
    [self postStateDidChange];
}

- (void)retryAfterPermissionChange {
    NSAssert([NSThread isMainThread], @"The gesture engine must be retried on the main thread.");
    if (_running && ![self refreshPermissionsRequestingAccess:NO]) {
        [self stop];
    }
    if (!_running) {
        [self start];
    } else {
        [self postStateDidChange];
    }
}

- (void)reload {
    if (!_running) {
        return;
    }
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(reloadOnMainThread)
                               withObject:nil
                            waitUntilDone:NO];
        return;
    }
    [self reloadOnMainThread];
}

- (void)reloadOnMainThread {
    if (_running) {
        [_gesture reload];
    }
}

- (void)stop {
    if (!_running) {
        return;
    }

    NSAssert([NSThread isMainThread], @"The gesture engine must stop on the main thread.");

    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];

    turnOffGestures();
    _running = NO;

    [_gesture release];
    _gesture = nil;
    [cursorWindow release];
    cursorWindow = nil;
    [self refreshPermissionsRequestingAccess:NO];
    [self postStateDidChange];
}

- (void)legacySettingsDidChange:(NSNotification *)notification {
    NSDictionary *newSettings = [notification userInfo];
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(applySettingsDictionary:)
                               withObject:newSettings
                            waitUntilDone:NO];
        return;
    }
    [self applySettingsDictionary:newSettings];
}

- (void)applySettingsDictionary:(NSDictionary *)newSettings {
    if (!_running || newSettings == nil) {
        return;
    }
    [Settings loadSettings2:newSettings];
    if (!enAll) {
        turnOffGestures();
    }
}

- (void)workspaceDidWake:(NSNotification *)notification {
    (void)notification;
    [self reload];
}

- (void)dealloc {
    if (_running) {
        [self stop];
    }
    [super dealloc];
}

@end
