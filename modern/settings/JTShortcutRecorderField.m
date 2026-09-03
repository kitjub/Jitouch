#import "JTShortcutRecorderField.h"

#import <ApplicationServices/ApplicationServices.h>

static NSUInteger JTDeviceIndependentCGFlags(NSEventModifierFlags flags) {
    return flags & (NSEventModifierFlagShift |
                    NSEventModifierFlagControl |
                    NSEventModifierFlagOption |
                    NSEventModifierFlagCommand);
}

static NSUInteger JTDeviceIndependentRawCGFlags(CGEventFlags flags) {
    return flags & (kCGEventFlagMaskShift |
                    kCGEventFlagMaskControl |
                    kCGEventFlagMaskAlternate |
                    kCGEventFlagMaskCommand);
}

static NSString *JTKeyName(CGKeyCode keyCode) {
    static NSDictionary<NSNumber *, NSString *> *names;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = @{
            @0:@"A", @1:@"S", @2:@"D", @3:@"F", @4:@"H", @5:@"G", @6:@"Z", @7:@"X",
            @8:@"C", @9:@"V", @11:@"B", @12:@"Q", @13:@"W", @14:@"E", @15:@"R",
            @16:@"Y", @17:@"T", @18:@"1", @19:@"2", @20:@"3", @21:@"4", @22:@"6",
            @23:@"5", @24:@"=", @25:@"9", @26:@"7", @27:@"−", @28:@"8", @29:@"0",
            @30:@"]", @31:@"O", @32:@"U", @33:@"[", @34:@"I", @35:@"P", @36:@"↩",
            @37:@"L", @38:@"J", @39:@"'", @40:@"K", @41:@";", @42:@"\\", @43:@",",
            @44:@"/", @45:@"N", @46:@"M", @47:@".", @48:@"⇥", @49:@"Space", @50:@"`",
            @51:@"⌫", @53:@"⎋", @115:@"Home", @116:@"Page Up", @117:@"⌦",
            @119:@"End", @121:@"Page Down", @123:@"←", @124:@"→", @125:@"↓", @126:@"↑",
            @122:@"F1", @120:@"F2", @99:@"F3", @118:@"F4", @96:@"F5", @97:@"F6",
            @98:@"F7", @100:@"F8", @101:@"F9", @109:@"F10", @103:@"F11", @111:@"F12",
        };
    });
    return names[@(keyCode)] ?: [NSString stringWithFormat:@"Key %u", keyCode];
}

static NSString *JTShortcutDescription(NSUInteger flags, CGKeyCode keyCode) {
    NSMutableString *value = [NSMutableString string];
    if (flags & kCGEventFlagMaskControl) [value appendString:@"⌃"];
    if (flags & kCGEventFlagMaskAlternate) [value appendString:@"⌥"];
    if (flags & kCGEventFlagMaskShift) [value appendString:@"⇧"];
    if (flags & kCGEventFlagMaskCommand) [value appendString:@"⌘"];
    [value appendString:JTKeyName(keyCode)];
    return value;
}

@interface JTShortcutRecorderField ()
@property(nonatomic, assign) CFMachPortRef shortcutEventTap;
@property(nonatomic, assign) CFRunLoopSourceRef shortcutEventTapSource;
- (void)startShortcutEventTap;
- (void)stopShortcutEventTap;
- (void)captureKeyCode:(CGKeyCode)keyCode modifierFlags:(NSUInteger)modifierFlags;
@end

static CGEventRef JTShortcutRecorderEventTapCallback(CGEventTapProxy proxy,
                                                      CGEventType type,
                                                      CGEventRef event,
                                                      void *userInfo) {
    (void)proxy;
    JTShortcutRecorderField *field = (__bridge JTShortcutRecorderField *)userInfo;
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) {
        if (field.shortcutEventTap != NULL) CGEventTapEnable(field.shortcutEventTap, true);
        return event;
    }
    if (type != kCGEventKeyDown || field.window.firstResponder != field) return event;

    CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event,
                                                               kCGKeyboardEventKeycode);
    NSUInteger flags = JTDeviceIndependentRawCGFlags(CGEventGetFlags(event));
    [field captureKeyCode:keyCode modifierFlags:flags];

    // System-reserved combinations such as Control-Down are consumed here so
    // Mission Control/App Expose cannot run before the recorder sees them.
    return NULL;
}

@implementation JTShortcutRecorderField

@synthesize hasRecordedShortcut = _hasRecordedShortcut;

- (void)captureEvent:(NSEvent *)event {
    [self captureKeyCode:event.keyCode
           modifierFlags:JTDeviceIndependentCGFlags(event.modifierFlags)];
}

- (void)captureKeyCode:(CGKeyCode)keyCode modifierFlags:(NSUInteger)modifierFlags {
    self.modifierFlags = modifierFlags;
    _keyCode = keyCode;
    _hasRecordedShortcut = YES;
    self.stringValue = JTShortcutDescription(self.modifierFlags, self.keyCode);
    if (self.recordingHandler != nil) {
        self.recordingHandler(self);
    }
    if (self.target != nil && self.action != NULL) {
        [NSApp sendAction:self.action to:self.target from:self];
    }
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.editable = NO;
        self.selectable = NO;
        self.bordered = YES;
        self.alignment = NSTextAlignmentCenter;
        self.placeholderString = @"Click, then press a shortcut";
        self.focusRingType = NSFocusRingTypeExterior;
    }
    return self;
}

- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder {
    BOOL became = [super becomeFirstResponder];
    if (became) {
        self.stringValue = @"Type shortcut…";
        [self startShortcutEventTap];
    }
    return became;
}
- (BOOL)resignFirstResponder {
    BOOL resigned = [super resignFirstResponder];
    if (resigned) {
        [self stopShortcutEventTap];
        self.stringValue = self.hasRecordedShortcut
            ? JTShortcutDescription(self.modifierFlags, self.keyCode)
            : @"";
    }
    return resigned;
}

- (void)startShortcutEventTap {
    if (self.shortcutEventTap != NULL) return;
    CGEventMask mask = CGEventMaskBit(kCGEventKeyDown);
    CFMachPortRef tap = CGEventTapCreate(kCGSessionEventTap,
                                        kCGHeadInsertEventTap,
                                        kCGEventTapOptionDefault,
                                        mask,
                                        JTShortcutRecorderEventTapCallback,
                                        (__bridge void *)self);
    if (tap == NULL) return;

    CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0);
    if (source == NULL) {
        CFRelease(tap);
        return;
    }
    self.shortcutEventTap = tap;
    self.shortcutEventTapSource = source;
    CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
    CGEventTapEnable(tap, true);
}

- (void)stopShortcutEventTap {
    if (self.shortcutEventTapSource != NULL) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), self.shortcutEventTapSource,
                              kCFRunLoopCommonModes);
        CFRelease(self.shortcutEventTapSource);
        self.shortcutEventTapSource = NULL;
    }
    if (self.shortcutEventTap != NULL) {
        CFMachPortInvalidate(self.shortcutEventTap);
        CFRelease(self.shortcutEventTap);
        self.shortcutEventTap = NULL;
    }
}

- (void)dealloc {
    [self stopShortcutEventTap];
}

- (void)mouseDown:(NSEvent *)event {
    (void)event;
    [self.window makeFirstResponder:self];
}

- (void)keyDown:(NSEvent *)event {
    [self captureEvent:event];
}

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    // Command shortcuts normally leave a text field through the key-equivalent
    // dispatch path (for example Command-Q or Command-comma). Capture them while
    // this recorder is the first responder instead of invoking the app menu.
    if (self.window.firstResponder == self && event.type == NSEventTypeKeyDown) {
        [self captureEvent:event];
        return YES;
    }
    return [super performKeyEquivalent:event];
}

- (void)setModifierFlags:(NSUInteger)modifierFlags {
    // Preserve historical raw flag values. Some released preference files have
    // extra low bits; display ignores them, but editing another field must not
    // silently normalize them away.
    _modifierFlags = modifierFlags;
    if (_hasRecordedShortcut) {
        self.stringValue = JTShortcutDescription(_modifierFlags, self.keyCode);
    }
}

- (void)setKeyCode:(CGKeyCode)keyCode {
    _keyCode = keyCode;
    if (_hasRecordedShortcut) {
        self.stringValue = JTShortcutDescription(self.modifierFlags, _keyCode);
    }
}

- (void)setModifierFlags:(NSUInteger)modifierFlags keyCode:(CGKeyCode)keyCode {
    _modifierFlags = modifierFlags;
    _keyCode = keyCode;
    _hasRecordedShortcut = YES;
    self.stringValue = JTShortcutDescription(_modifierFlags, _keyCode);
}

- (void)clearShortcut {
    _modifierFlags = 0;
    _keyCode = 0;
    _hasRecordedShortcut = NO;
    self.stringValue = @"";
}

@end
