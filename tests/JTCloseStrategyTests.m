#import <Cocoa/Cocoa.h>

#import "JTCloseStrategy.h"

static NSUInteger assertions = 0;

static void Assert(BOOL condition, NSString *message) {
    assertions++;
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

int main(void) {
    @autoreleasepool {
        Assert(!JTAXRoleIsTransientCloseSurface(kAXWindowRole,
                                                 kAXStandardWindowSubrole),
               @"standard windows retain Cmd-W tab/document semantics");
        Assert(JTAXRoleIsTransientCloseSurface(kAXWindowRole, kAXDialogSubrole),
               @"dialogs are dismissed directly");
        Assert(JTAXRoleIsTransientCloseSurface(kAXWindowRole,
                                                kAXSystemDialogSubrole),
               @"system dialogs are dismissed directly");
        Assert(JTAXRoleIsTransientCloseSurface(kAXWindowRole,
                                                kAXFloatingWindowSubrole),
               @"floating panels are dismissed directly");
        Assert(JTAXRoleIsTransientCloseSurface(kAXWindowRole,
                                                kAXSystemFloatingWindowSubrole),
               @"system floating panels are dismissed directly");
        Assert(JTAXRoleIsTransientCloseSurface(kAXWindowRole,
                                                CFSTR("AXFrameworkPreviewWindow")),
               @"future framework-owned panel subroles are dismissed directly");
        Assert(JTAXRoleIsTransientCloseSurface(kAXSheetRole, NULL),
               @"sheets are dismissed directly");
        Assert(JTAXRoleIsTransientCloseSurface(kAXDrawerRole, NULL),
               @"drawers are dismissed directly");
        Assert(JTAXRoleIsTransientCloseSurface(kAXPopoverRole, NULL),
               @"popovers are dismissed directly");
        Assert(!JTAXRoleIsTransientCloseSurface(kAXButtonRole,
                                                 kAXCloseButtonSubrole),
               @"ordinary descendants are not mistaken for surfaces");
        Assert(!JTAXRoleIsTransientCloseSurface(kAXWindowRole, NULL),
               @"unknown windows keep the conservative Cmd-W fallback");
        Assert(JTAXSurfaceUsesDirectClose(kAXWindowRole,
                                          kAXStandardWindowSubrole, YES, NO),
               @"close-only usable controls identify framework panels");
        Assert(!JTAXSurfaceUsesDirectClose(kAXWindowRole,
                                           kAXStandardWindowSubrole, YES, YES),
               @"ordinary usable window controls retain Cmd-W tab/document semantics");
        Assert(!JTAXSurfaceUsesDirectClose(kAXWindowRole,
                                           kAXStandardWindowSubrole, NO, NO),
               @"disabled full-screen controls are not misclassified");
        Assert(JTAXSurfaceUsesDirectClose(kAXPopoverRole, NULL, NO, NO),
               @"known transient roles remain direct-close surfaces");
        NSLog(@"PASS: %lu close-strategy assertions", (unsigned long)assertions);
    }
    return 0;
}
