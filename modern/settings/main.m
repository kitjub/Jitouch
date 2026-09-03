#import <Cocoa/Cocoa.h>

#import "JTSettingsAppDelegate.h"

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        JTSettingsAppDelegate *delegate = [[JTSettingsAppDelegate alloc] init];
        application.delegate = delegate;
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [application run];
        (void)delegate; // Keep the delegate alive for the lifetime of NSApplication.
    }
    return 0;
}
