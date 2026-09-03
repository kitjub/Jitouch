#import "JTCloseStrategy.h"

static BOOL JTStringEquals(CFStringRef value, CFStringRef expected) {
    return value != NULL && expected != NULL && CFEqual(value, expected);
}

BOOL JTAXRoleIsTransientCloseSurface(CFStringRef role, CFStringRef subrole) {
    if (JTStringEquals(role, kAXSheetRole) ||
        JTStringEquals(role, kAXDrawerRole) ||
        JTStringEquals(role, kAXPopoverRole)) {
        return YES;
    }
    if (!JTStringEquals(role, kAXWindowRole)) return NO;

    if (JTStringEquals(subrole, kAXStandardWindowSubrole)) return NO;

    // Quick Look and other framework-owned panels can expose private/new
    // window subroles. Treat every explicit non-standard window subrole as a
    // transient surface; a missing subrole remains conservative and uses
    // Cmd-W. Full-screen document windows continue to report the standard
    // window subrole and therefore retain tab/document semantics.
    return subrole != NULL;
}

BOOL JTAXSurfaceUsesDirectClose(CFStringRef role, CFStringRef subrole,
                                BOOL hasUsableCloseButton,
                                BOOL hasUsableMinimizeButton) {
    if (JTAXRoleIsTransientCloseSurface(role, subrole)) return YES;
    return JTStringEquals(role, kAXWindowRole) &&
           JTStringEquals(subrole, kAXStandardWindowSubrole) &&
           hasUsableCloseButton && !hasUsableMinimizeButton;
}

static CFTypeRef JTCopyAXAttribute(AXUIElementRef element, CFStringRef attribute) {
    CFTypeRef value = NULL;
    if (element == NULL ||
        AXUIElementCopyAttributeValue(element, attribute, &value) != kAXErrorSuccess) {
        return NULL;
    }
    return value;
}

static BOOL JTPressAXButtonAttribute(AXUIElementRef surface, CFStringRef attribute) {
    AXUIElementRef button = (AXUIElementRef)JTCopyAXAttribute(surface, attribute);
    if (button == NULL) return NO;
    AXError error = AXUIElementPerformAction(button, kAXPressAction);
    CFRelease(button);
    return error == kAXErrorSuccess;
}


static BOOL JTAXControlIsUsable(AXUIElementRef element, CFStringRef attribute) {
    AXUIElementRef control = (AXUIElementRef)JTCopyAXAttribute(element, attribute);
    if (control == NULL) return NO;

    CFTypeRef enabledValue = JTCopyAXAttribute(control, kAXEnabledAttribute);
    BOOL enabled = YES;
    if (enabledValue != NULL && CFGetTypeID(enabledValue) == CFBooleanGetTypeID()) {
        enabled = CFBooleanGetValue((CFBooleanRef)enabledValue);
    }
    if (enabledValue) CFRelease(enabledValue);

    CFTypeRef hiddenValue = JTCopyAXAttribute(control, kAXHiddenAttribute);
    if (hiddenValue != NULL && CFGetTypeID(hiddenValue) == CFBooleanGetTypeID() &&
        CFBooleanGetValue((CFBooleanRef)hiddenValue)) {
        enabled = NO;
    }
    if (hiddenValue) CFRelease(hiddenValue);

    CFTypeRef sizeValue = JTCopyAXAttribute(control, kAXSizeAttribute);
    if (sizeValue != NULL && CFGetTypeID(sizeValue) == AXValueGetTypeID() &&
        AXValueGetType((AXValueRef)sizeValue) == kAXValueCGSizeType) {
        CGSize size = CGSizeZero;
        if (AXValueGetValue((AXValueRef)sizeValue, kAXValueCGSizeType, &size) &&
            (size.width <= 0.0 || size.height <= 0.0)) {
            enabled = NO;
        }
    }
    if (sizeValue) CFRelease(sizeValue);
    CFRelease(control);
    return enabled;
}

static BOOL JTAXWindowCanMinimize(AXUIElementRef window) {
    if (!JTAXControlIsUsable(window, kAXMinimizeButtonAttribute)) return NO;
    Boolean settable = false;
    AXError error = AXUIElementIsAttributeSettable(window, kAXMinimizedAttribute,
                                                   &settable);
    return error == kAXErrorSuccess ? settable : YES;
}

typedef enum {
    JTCloseResolutionNotSurface = 0,
    JTCloseResolutionUseCommandW = 1,
    JTCloseResolutionDismissed = 2,
    JTCloseResolutionNeedsEscape = 3,
} JTCloseResolution;

static JTCloseResolution JTResolveAndCloseSurface(AXUIElementRef candidate,
                                                   const char *source) {
    if (candidate == NULL) return JTCloseResolutionNotSurface;

    CFStringRef role = (CFStringRef)JTCopyAXAttribute(candidate, kAXRoleAttribute);
    CFStringRef subrole = (CFStringRef)JTCopyAXAttribute(candidate, kAXSubroleAttribute);
    BOOL isSurface = JTStringEquals(role, kAXWindowRole) ||
                     JTStringEquals(role, kAXSheetRole) ||
                     JTStringEquals(role, kAXDrawerRole) ||
                     JTStringEquals(role, kAXPopoverRole);
    if (!isSurface) {
        if (role) CFRelease(role);
        if (subrole) CFRelease(subrole);
        return JTCloseResolutionNotSurface;
    }

    BOOL closeUsable = JTAXControlIsUsable(candidate, kAXCloseButtonAttribute);
    BOOL minimizeUsable = JTAXWindowCanMinimize(candidate);
    BOOL direct = JTAXSurfaceUsesDirectClose(role, subrole, closeUsable,
                                              minimizeUsable);
    (void)source;
    if (role) CFRelease(role);
    if (subrole) CFRelease(subrole);

    if (!direct) return JTCloseResolutionUseCommandW;
    BOOL dismissed = JTPressAXButtonAttribute(candidate, kAXCloseButtonAttribute) ||
                     JTPressAXButtonAttribute(candidate, kAXCancelButtonAttribute) ||
                     AXUIElementPerformAction(candidate, kAXCancelAction) == kAXErrorSuccess;
    return dismissed ? JTCloseResolutionDismissed : JTCloseResolutionNeedsEscape;
}

static JTCloseAttempt JTCloseAttemptForResolution(JTCloseResolution resolution) {
    if (resolution == JTCloseResolutionDismissed) return JTCloseAttemptDismissed;
    if (resolution == JTCloseResolutionNeedsEscape) return JTCloseAttemptNeedsEscape;
    return JTCloseAttemptNotTransient;
}

JTCloseAttempt JTTryDismissTransientCloseSurface(AXUIElementRef element) {
    if (element == NULL) {
        return JTCloseAttemptNotTransient;
    }

    // Parent chains are not reliable across framework and process boundaries
    // (VisionKit, web content, PDF views, and Quick Look can terminate them).
    // Ask Accessibility for the owning top-level surface/window first.
    AXUIElementRef topLevel = (AXUIElementRef)JTCopyAXAttribute(
        element, kAXTopLevelUIElementAttribute);
    JTCloseResolution resolution = JTResolveAndCloseSurface(topLevel, "topLevel");
    if (topLevel) CFRelease(topLevel);
    if (resolution != JTCloseResolutionNotSurface)
        return JTCloseAttemptForResolution(resolution);

    AXUIElementRef window = (AXUIElementRef)JTCopyAXAttribute(element,
                                                              kAXWindowAttribute);
    resolution = JTResolveAndCloseSurface(window, "window");
    if (window) CFRelease(window);
    if (resolution != JTCloseResolutionNotSurface)
        return JTCloseAttemptForResolution(resolution);

    AXUIElementRef current = (AXUIElementRef)CFRetain(element);
    for (NSUInteger depth = 0; current != NULL && depth < 32; depth++) {
        resolution = JTResolveAndCloseSurface(current, "parent");
        if (resolution != JTCloseResolutionNotSurface) {
            CFRelease(current);
            return JTCloseAttemptForResolution(resolution);
        }

        AXUIElementRef parent = (AXUIElementRef)JTCopyAXAttribute(current,
                                                                  kAXParentAttribute);
        if (parent == NULL || CFEqual(parent, current)) {
            if (parent) CFRelease(parent);
            break;
        }
        CFRelease(current);
        current = parent;
    }
    if (current) CFRelease(current);
    return JTCloseAttemptNotTransient;
}
