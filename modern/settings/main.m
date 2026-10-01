#import <Cocoa/Cocoa.h>

#import "JTSettingsAppDelegate.h"

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        // A second engine would run every gesture twice, e.g. when both the
        // login item and the installer's LaunchAgent start the app.
        NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
        if (bundleIdentifier != nil) {
            for (NSRunningApplication *other in
                 [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier]) {
                if (other.processIdentifier != getpid()) {
                    return 0;
                }
            }
        }
        NSApplication *application = [NSApplication sharedApplication];
        JTSettingsAppDelegate *delegate = [[JTSettingsAppDelegate alloc] init];
        application.delegate = delegate;
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [application run];
        (void)delegate; // Keep the delegate alive for the lifetime of NSApplication.
    }
    return 0;
}
