#import <ApplicationServices/ApplicationServices.h>

typedef enum {
    JTCloseAttemptNotTransient = 0,
    JTCloseAttemptDismissed = 1,
    JTCloseAttemptNeedsEscape = 2,
} JTCloseAttempt;

/// Returns whether an accessibility role represents UI that should be
/// dismissed directly instead of receiving the document/tab shortcut Cmd-W.
BOOL JTAXRoleIsTransientCloseSurface(CFStringRef role, CFStringRef subrole);

/// Standard-subrole windows can still be framework panels (Quick Look is one
/// example). A close-only window without minimization capability should use
/// its accessibility close control rather than document/tab Cmd-W semantics.
BOOL JTAXSurfaceUsesDirectClose(CFStringRef role, CFStringRef subrole,
                                BOOL hasUsableCloseButton,
                                BOOL hasUsableMinimizeButton);

/// Walks from the element under the pointer to its nearest transient ancestor.
/// It presses that surface's Close/Cancel control when available; callers
/// should send Escape only for JTCloseAttemptNeedsEscape and Cmd-W only for
/// JTCloseAttemptNotTransient.
JTCloseAttempt JTTryDismissTransientCloseSurface(AXUIElementRef element);
