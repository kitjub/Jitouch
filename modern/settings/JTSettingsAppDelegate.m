#import "JTSettingsAppDelegate.h"

#import "JTSettingsStore.h"
#import "JTGestureEditorController.h"
#import "../engine/JTEngineController.h"

static NSArray<NSString *> *JTTrackpadGestureCatalog(void) {
    return @[
        @"One-Fix Left-Tap", @"One-Fix Right-Tap", @"One-Fix One-Slide",
        @"One-Fix Two-Slide-Up", @"One-Fix Two-Slide-Down",
        @"One-Fix-Press Two-Slide-Up", @"One-Fix-Press Two-Slide-Down",
        @"Two-Fix Index-Double-Tap", @"Two-Fix Middle-Double-Tap",
        @"Two-Fix Ring-Double-Tap", @"Two-Fix One-Slide-Up",
        @"Two-Fix One-Slide-Down", @"Two-Fix One-Slide-Left",
        @"Two-Fix One-Slide-Right", @"Three-Finger Tap", @"Three-Finger Click",
        @"Three-Finger Pinch-In", @"Three-Finger Pinch-Out", @"Three-Swipe-Up",
        @"Three-Swipe-Down", @"Three-Swipe-Left", @"Three-Swipe-Right",
        @"Four-Finger Tap", @"Four-Finger Click", @"Four-Swipe-Up",
        @"Four-Swipe-Down", @"Four-Swipe-Left", @"Four-Swipe-Right",
        @"Pinky-To-Index", @"Index-To-Pinky", @"Left-Side Scroll",
        @"Right-Side Scroll", @"Left-Side Volume Scrub",
        @"Right-Side Volume Scrub", @"All Unassigned Gestures"
    ];
}

static NSArray<NSString *> *JTMagicMouseGestureCatalog(void) {
    return @[
        @"Middle-Fix Index-Near-Tap", @"Middle-Fix Index-Far-Tap",
        @"Index-Fix Middle-Near-Tap", @"Index-Fix Middle-Far-Tap",
        @"Middle-Fix Index-Slide-Out", @"Middle-Fix Index-Slide-In",
        @"Index-Fix Middle-Slide-Out", @"Index-Fix Middle-Slide-In",
        @"Three-Swipe-Left", @"Three-Swipe-Right", @"Three-Swipe-Up",
        @"Three-Swipe-Down", @"Three-Finger Click", @"V-Shape", @"Middle Click",
        @"Two-Fix One-Slide-Up", @"Two-Fix One-Slide-Down",
        @"Two-Fix One-Slide-Left", @"Two-Fix One-Slide-Right", @"Thumb",
        @"All Unassigned Gestures"
    ];
}

static NSArray<NSString *> *JTRecognitionGestureCatalog(void) {
    return @[
        @"A", @"B", @"C", @"D", @"E", @"F", @"G", @"H", @"J", @"K",
        @"L", @"M", @"N", @"O", @"P", @"Q", @"R", @"S", @"T", @"U",
        @"V", @"W", @"X", @"Y", @"Z", @"Up", @"Down", @"Left", @"Right",
        @"Left-Right", @"Right-Left", @"Up-Left", @"Up-Right", @"Left-Up",
        @"Right-Up", @"/ Up", @"/ Down", @"\\ Up", @"\\ Down",
        @"All Unassigned Gestures"
    ];
}

@interface JTSettingsAppDelegate ()
@property(nonatomic, strong) JTSettingsStore *settingsStore;
@property(nonatomic, strong) JTEngineController *engineController;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *enabledMenuItem;
@property(nonatomic, strong) NSWindow *settingsWindow;
@property(nonatomic, strong) NSSwitch *enabledSwitch;
@property(nonatomic, strong) NSButton *showIconCheckbox;
@property(nonatomic, strong) NSSlider *clickSpeedSlider;
@property(nonatomic, strong) NSSlider *sensitivitySlider;
@property(nonatomic, strong) NSPopUpButton *logLevelPopup;
@property(nonatomic, strong) NSButton *trackpadCheckbox;
@property(nonatomic, strong) NSSegmentedControl *trackpadHandedness;
@property(nonatomic, strong) NSButton *nativeDragProtectionCheckbox;
@property(nonatomic, strong) NSButton *mouseCheckbox;
@property(nonatomic, strong) NSSegmentedControl *mouseHandedness;
@property(nonatomic, strong) NSButton *recognitionTrackpadCheckbox;
@property(nonatomic, strong) NSButton *recognitionMouseCheckbox;
@property(nonatomic, strong) NSTextField *stateLabel;
@property(nonatomic, strong) NSButton *permissionRetryButton;
@property(nonatomic, strong) NSButton *privacySettingsButton;
@property(nonatomic, strong) JTGestureEditorController *trackpadEditor;
@property(nonatomic, strong) JTGestureEditorController *mouseEditor;
@property(nonatomic, strong) JTGestureEditorController *recognitionEditor;
@property(nonatomic, strong) id globalEmergencyPauseMonitor;
@property(nonatomic, strong) id localEmergencyPauseMonitor;
@end

@implementation JTSettingsAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.settingsStore = [[JTSettingsStore alloc] init];
    self.engineController = [[JTEngineController alloc] init];
    [self.engineController start];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(engineStateDidChange:)
               name:JTEngineStateDidChangeNotification
             object:self.engineController];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(settingsDidChange:)
               name:JTSettingsStoreDidChangeNotification
             object:self.settingsStore];

    [self buildStatusItem];
    [self installEmergencyPauseHotKey];
    [self buildSettingsWindow];
    [self refreshControls];
    if (!self.engineController.isRunning) {
        [self showSettings:nil];
    }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)hasVisibleWindows {
    [self showSettings:nil];
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    if (self.globalEmergencyPauseMonitor != nil) {
        [NSEvent removeMonitor:self.globalEmergencyPauseMonitor];
        self.globalEmergencyPauseMonitor = nil;
    }
    if (self.localEmergencyPauseMonitor != nil) {
        [NSEvent removeMonitor:self.localEmergencyPauseMonitor];
        self.localEmergencyPauseMonitor = nil;
    }
    [self.engineController stop];
    self.engineController = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Construction

- (void)buildStatusItem {
    if (self.statusItem != nil) {
        return;
    }
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    self.statusItem.button.toolTip = @"Jitouch Modern";

    NSImage *image = [NSImage imageWithSystemSymbolName:@"hand.tap"
                               accessibilityDescription:@"Jitouch Modern"];
    image.template = YES;
    self.statusItem.button.image = image;

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Jitouch Modern"];
    self.enabledMenuItem = [[NSMenuItem alloc] initWithTitle:@"Enable Jitouch Modern"
                                                     action:@selector(toggleEnabled:)
                                              keyEquivalent:@""];
    self.enabledMenuItem.target = self;
    [menu addItem:self.enabledMenuItem];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *settingsItem = [[NSMenuItem alloc] initWithTitle:@"Settings…"
                                                          action:@selector(showSettings:)
                                                   keyEquivalent:@","];
    settingsItem.target = self;
    [menu addItem:settingsItem];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *emergencyItem = [[NSMenuItem alloc]
        initWithTitle:@"Emergency Pause Gestures"
               action:@selector(emergencyPause:)
        keyEquivalent:@"\e"];
    emergencyItem.keyEquivalentModifierMask =
        NSEventModifierFlagControl | NSEventModifierFlagOption |
        NSEventModifierFlagCommand;
    emergencyItem.target = self;
    [menu addItem:emergencyItem];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Jitouch Modern"
                                                      action:@selector(quit:)
                                               keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];
    self.statusItem.menu = menu;
}

- (void)buildSettingsWindow {
    NSRect frame = NSMakeRect(0, 0, 900, 680);
    self.settingsWindow = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                            NSWindowStyleMaskMiniaturizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.settingsWindow.title = @"Jitouch Modern Settings";
    self.settingsWindow.delegate = self;
    self.settingsWindow.releasedWhenClosed = NO;
    [self.settingsWindow center];

    NSView *content = self.settingsWindow.contentView;

    NSTextField *title = [NSTextField labelWithString:@"Jitouch Modern Settings"];
    title.font = [NSFont systemFontOfSize:22 weight:NSFontWeightSemibold];

    NSTextField *explanation = [NSTextField wrappingLabelWithString:
        @"Use trackpad and Magic Mouse gestures with your existing Jitouch configuration."];
    explanation.textColor = NSColor.secondaryLabelColor;

    NSTabView *tabs = [[NSTabView alloc] initWithFrame:NSZeroRect];
    tabs.translatesAutoresizingMaskIntoConstraints = NO;
    [tabs addTabViewItem:[self generalTab]];
    [tabs addTabViewItem:[self deviceTabWithIdentifier:@"Trackpad" isTrackpad:YES]];
    [tabs addTabViewItem:[self deviceTabWithIdentifier:@"Magic Mouse" isTrackpad:NO]];
    [tabs addTabViewItem:[self recognitionTab]];

    NSStackView *stack = [NSStackView stackViewWithViews:@[title, explanation, tabs]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:28],
        [stack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-28],
        [stack.topAnchor constraintEqualToAnchor:content.topAnchor constant:28],
        [explanation.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [tabs.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [tabs.heightAnchor constraintEqualToConstant:520],
    ]];
}

- (NSTabViewItem *)generalTab {
    self.enabledSwitch = [[NSSwitch alloc] initWithFrame:NSZeroRect];
    self.enabledSwitch.target = self;
    self.enabledSwitch.action = @selector(toggleEnabled:);

    self.showIconCheckbox = [self checkboxWithTitle:@"Show icon in menu bar"
                                             action:@selector(generalSettingChanged:)];

    self.clickSpeedSlider = [NSSlider sliderWithValue:0.25
                                            minValue:0.1
                                            maxValue:0.4
                                              target:self
                                              action:@selector(generalSettingChanged:)];
    self.clickSpeedSlider.numberOfTickMarks = 11;
    self.clickSpeedSlider.allowsTickMarkValuesOnly = YES;

    self.sensitivitySlider = [NSSlider sliderWithValue:4.6666
                                             minValue:4.0
                                             maxValue:10.0
                                               target:self
                                               action:@selector(generalSettingChanged:)];
    self.sensitivitySlider.numberOfTickMarks = 10;
    self.sensitivitySlider.allowsTickMarkValuesOnly = YES;

    self.logLevelPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    for (NSDictionary *item in @[
        @{@"title": @"Quiet", @"tag": @(-1)},
        @{@"title": @"Default", @"tag": @0},
        @{@"title": @"Info", @"tag": @1},
        @{@"title": @"Debug", @"tag": @2},
    ]) {
        [self.logLevelPopup addItemWithTitle:item[@"title"]];
        self.logLevelPopup.lastItem.tag = [item[@"tag"] integerValue];
    }
    self.logLevelPopup.target = self;
    self.logLevelPopup.action = @selector(generalSettingChanged:);

    self.stateLabel = [NSTextField labelWithString:@""];
    self.stateLabel.textColor = NSColor.secondaryLabelColor;
    self.stateLabel.maximumNumberOfLines = 3;
    self.permissionRetryButton = [NSButton buttonWithTitle:@"Check Permissions / Retry Engine"
                                                    target:self
                                                    action:@selector(retryEngine:)];
    self.privacySettingsButton = [NSButton buttonWithTitle:@"Open Privacy & Security…"
                                                    target:self
                                                    action:@selector(openPrivacySettings:)];
    NSStackView *permissionButtons = [NSStackView stackViewWithViews:@[
        self.permissionRetryButton,
        self.privacySettingsButton,
    ]];
    permissionButtons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    permissionButtons.spacing = 8;

    NSStackView *content = [self verticalContentWithViews:@[
        [self labeledRow:@"Enable all gestures" control:self.enabledSwitch],
        self.stateLabel,
        permissionButtons,
        self.showIconCheckbox,
        [self labeledRow:@"Tap speed (slow → fast)" control:self.clickSpeedSlider],
        [self labeledRow:@"Sensitivity (soft → hard)" control:self.sensitivitySlider],
        [self labeledRow:@"Logging" control:self.logLevelPopup],
    ]];
    return [self tabWithLabel:@"General" content:content];
}

- (NSTabViewItem *)deviceTabWithIdentifier:(NSString *)identifier isTrackpad:(BOOL)isTrackpad {
    NSButton *enabled = [self checkboxWithTitle:[NSString stringWithFormat:@"Enable Jitouch for %@", identifier]
                                         action:@selector(deviceSettingChanged:)];
    NSSegmentedControl *handedness = [NSSegmentedControl
        segmentedControlWithLabels:@[@"Right-handed", @"Left-handed"]
                    trackingMode:NSSegmentSwitchTrackingSelectOne
                          target:self
                          action:@selector(deviceSettingChanged:)];
    handedness.selectedSegment = 0;

    if (isTrackpad) {
        self.trackpadCheckbox = enabled;
        self.trackpadHandedness = handedness;
        self.nativeDragProtectionCheckbox = [self
            checkboxWithTitle:@"Protect macOS three-finger drag (tap gestures stay available)"
                       action:@selector(deviceSettingChanged:)];
        self.nativeDragProtectionCheckbox.toolTip =
            @"Allows Three-Finger Tap and Two-Fix Double-Tap, while blocking motion and click gestures that compete with macOS dragging.";
        self.trackpadEditor = [[JTGestureEditorController alloc]
            initWithStore:self.settingsStore
              commandsKey:JTTrackpadCommandsKey
              deviceTitle:@"Trackpad"
           gestureCatalog:JTTrackpadGestureCatalog()];
    } else {
        self.mouseCheckbox = enabled;
        self.mouseHandedness = handedness;
        self.mouseEditor = [[JTGestureEditorController alloc]
            initWithStore:self.settingsStore
              commandsKey:JTMagicMouseCommandsKey
              deviceTitle:@"Magic Mouse"
           gestureCatalog:JTMagicMouseGestureCatalog()];
    }

    JTGestureEditorController *editor = isTrackpad ? self.trackpadEditor : self.mouseEditor;
    [editor.view.widthAnchor constraintEqualToConstant:790].active = YES;
    [editor.view.heightAnchor constraintEqualToConstant:isTrackpad ? 365 : 410].active = YES;
    NSArray<NSView *> *views = isTrackpad
        ? @[enabled,
            [self labeledRow:@"Handedness" control:handedness],
            self.nativeDragProtectionCheckbox,
            editor.view]
        : @[enabled,
            [self labeledRow:@"Handedness" control:handedness],
            editor.view];
    NSStackView *content = [self verticalContentWithViews:views];
    return [self tabWithLabel:identifier content:content];
}

- (NSTabViewItem *)recognitionTab {
    self.recognitionTrackpadCheckbox = [self checkboxWithTitle:@"Enable drawing on Trackpad"
                                                        action:@selector(recognitionSettingChanged:)];
    self.recognitionMouseCheckbox = [self checkboxWithTitle:@"Enable drawing on Magic Mouse"
                                                   action:@selector(recognitionSettingChanged:)];
    self.recognitionEditor = [[JTGestureEditorController alloc]
        initWithStore:self.settingsStore
          commandsKey:JTRecognitionCommandsKey
          deviceTitle:@"Drawing"
       gestureCatalog:JTRecognitionGestureCatalog()];
    [self.recognitionEditor.view.widthAnchor constraintEqualToConstant:790].active = YES;
    [self.recognitionEditor.view.heightAnchor constraintEqualToConstant:395].active = YES;
    NSStackView *content = [self verticalContentWithViews:@[
        self.recognitionTrackpadCheckbox,
        self.recognitionMouseCheckbox,
        self.recognitionEditor.view,
    ]];
    return [self tabWithLabel:@"Drawing" content:content];
}

- (NSTabViewItem *)tabWithLabel:(NSString *)label content:(NSView *)content {
    NSTabViewItem *item = [[NSTabViewItem alloc] initWithIdentifier:label];
    item.label = label;
    NSView *container = [[NSView alloc] initWithFrame:NSZeroRect];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:20],
        [content.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-20],
        [content.topAnchor constraintEqualToAnchor:container.topAnchor constant:20],
    ]];
    item.view = container;
    return item;
}

- (NSStackView *)verticalContentWithViews:(NSArray<NSView *> *)views {
    NSStackView *stack = [NSStackView stackViewWithViews:views];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 14;
    return stack;
}

- (NSStackView *)labeledRow:(NSString *)label control:(NSView *)control {
    NSTextField *text = [NSTextField labelWithString:label];
    NSStackView *row = [NSStackView stackViewWithViews:@[text, control]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.distribution = NSStackViewDistributionFill;
    [row.widthAnchor constraintEqualToConstant:440].active = YES;
    if ([control isKindOfClass:NSSlider.class]) {
        [control.widthAnchor constraintEqualToConstant:220].active = YES;
    }
    return row;
}

- (NSButton *)checkboxWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton checkboxWithTitle:title target:self action:action];
    return button;
}

#pragma mark - Actions

- (void)toggleEnabled:(id)sender {
    BOOL enabled;
    if (sender == self.enabledSwitch) {
        enabled = self.enabledSwitch.state == NSControlStateValueOn;
    } else {
        enabled = !self.settingsStore.isEnabled;
    }
    self.settingsStore.enabled = enabled;
    [self refreshControls];
}

- (BOOL)isEmergencyPauseEvent:(NSEvent *)event {
    NSEventModifierFlags modifiers = event.modifierFlags &
        NSEventModifierFlagDeviceIndependentFlagsMask;
    NSEventModifierFlags required = NSEventModifierFlagControl |
        NSEventModifierFlagOption | NSEventModifierFlagCommand;
    return event.type == NSEventTypeKeyDown && event.keyCode == 53 &&
           (modifiers & (required | NSEventModifierFlagShift)) == required;
}

- (void)installEmergencyPauseHotKey {
    if (self.globalEmergencyPauseMonitor != nil) return;
    __weak typeof(self) weakSelf = self;
    self.globalEmergencyPauseMonitor = [NSEvent
        addGlobalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                     handler:^(NSEvent *event) {
        if ([weakSelf isEmergencyPauseEvent:event]) [weakSelf emergencyPause:nil];
    }];
    self.localEmergencyPauseMonitor = [NSEvent
        addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                    handler:^NSEvent *(NSEvent *event) {
        if ([weakSelf isEmergencyPauseEvent:event]) [weakSelf emergencyPause:nil];
        return event;
    }];
}

- (void)emergencyPause:(id)sender {
    (void)sender;
    if (!self.settingsStore.isEnabled) return;
    self.settingsStore.enabled = NO;
    [self refreshControls];
}

- (void)generalSettingChanged:(id)sender {
    if (sender == self.showIconCheckbox) {
        [self.settingsStore setBool:self.showIconCheckbox.state == NSControlStateValueOn
                            forKey:@"ShowIcon"];
    } else if (sender == self.clickSpeedSlider) {
        // The legacy UI presents speed while the engine stores the tap interval.
        [self.settingsStore setDouble:0.5 - self.clickSpeedSlider.doubleValue
                              forKey:@"ClickSpeed"];
    } else if (sender == self.sensitivitySlider) {
        [self.settingsStore setDouble:self.sensitivitySlider.doubleValue forKey:@"Sensitivity"];
    } else if (sender == self.logLevelPopup) {
        [self.settingsStore setInteger:self.logLevelPopup.selectedItem.tag forKey:@"LogLevel"];
    }
}

- (void)deviceSettingChanged:(id)sender {
    if (sender == self.trackpadCheckbox) {
        [self.settingsStore setBool:self.trackpadCheckbox.state == NSControlStateValueOn forKey:@"enTPAll"];
    } else if (sender == self.trackpadHandedness) {
        [self.settingsStore setInteger:self.trackpadHandedness.selectedSegment forKey:@"Handed"];
    } else if (sender == self.nativeDragProtectionCheckbox) {
        BOOL protectionEnabled =
            self.nativeDragProtectionCheckbox.state == NSControlStateValueOn;
        if (!protectionEnabled) {
            NSAlert *warning = [[NSAlert alloc] init];
            warning.messageText = @"Let Jitouch own moving three-finger gestures?";
            warning.informativeText =
                @"Turn off macOS three-finger dragging first. Running both can break dragging and pointer clicks. Passive tap gestures do not require turning protection off.";
            [warning addButtonWithTitle:@"Keep Protection"];
            [warning addButtonWithTitle:@"Disable Protection"];
            if ([warning runModal] != NSAlertSecondButtonReturn) {
                self.nativeDragProtectionCheckbox.state = NSControlStateValueOn;
                return;
            }
        }
        [self.settingsStore setBool:protectionEnabled
                             forKey:JTNativeThreeFingerDragProtectionKey];
    } else if (sender == self.mouseCheckbox) {
        [self.settingsStore setBool:self.mouseCheckbox.state == NSControlStateValueOn forKey:@"enMMAll"];
    } else if (sender == self.mouseHandedness) {
        [self.settingsStore setInteger:self.mouseHandedness.selectedSegment forKey:@"MMHanded"];
    }
}

- (void)recognitionSettingChanged:(id)sender {
    if (sender == self.recognitionTrackpadCheckbox) {
        [self.settingsStore setBool:self.recognitionTrackpadCheckbox.state == NSControlStateValueOn
                            forKey:@"enCharRegTP"];
    } else if (sender == self.recognitionMouseCheckbox) {
        [self.settingsStore setBool:self.recognitionMouseCheckbox.state == NSControlStateValueOn
                            forKey:@"enCharRegMM"];
    }
}

- (void)showSettings:(id)sender {
    [self.settingsStore reload];
    [self refreshControls];
    [NSApp activateIgnoringOtherApps:YES];
    [self.settingsWindow makeKeyAndOrderFront:nil];
}

- (void)quit:(id)sender {
    [NSApp terminate:sender];
}

- (void)retryEngine:(id)sender {
    (void)sender;
    [self.engineController retryAfterPermissionChange];
    [self refreshControls];
}

- (void)openPrivacySettings:(id)sender {
    (void)sender;
    NSString *anchor = self.engineController.inputMonitoringGranted
        ? @"Privacy_Accessibility"
        : @"Privacy_ListenEvent";
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:
        @"x-apple.systempreferences:com.apple.preference.security?%@", anchor]];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)settingsDidChange:(NSNotification *)notification {
    [self refreshControls];
}

- (void)engineStateDidChange:(NSNotification *)notification {
    (void)notification;
    [self refreshControls];
}

- (void)refreshControls {
    BOOL enabled = self.settingsStore.isEnabled;
    BOOL showIcon = [self.settingsStore boolForKey:@"ShowIcon" defaultValue:YES];
    [self applyStatusItemVisibility:showIcon];
    self.enabledSwitch.state = enabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.enabledMenuItem.state = enabled ? NSControlStateValueOn : NSControlStateValueOff;
    BOOL engineRunning = self.engineController.isRunning;
    if (!enabled) {
        self.stateLabel.stringValue = @"Gestures are paused.";
    } else if (!self.engineController.accessibilityGranted &&
               !self.engineController.inputMonitoringGranted) {
        self.stateLabel.stringValue = @"Permissions required: enable Jitouch Modern in Accessibility and Input Monitoring, then retry.";
    } else if (!self.engineController.accessibilityGranted) {
        self.stateLabel.stringValue = @"Permission required: enable Jitouch Modern in Accessibility, then retry.";
    } else if (!self.engineController.inputMonitoringGranted) {
        self.stateLabel.stringValue = @"Permission required: enable Jitouch Modern in Input Monitoring, then retry.";
    } else if (!engineRunning) {
        self.stateLabel.stringValue = @"Gesture engine is stopped. Check permissions and retry.";
    } else {
        self.stateLabel.stringValue = @"Gestures are active.";
    }
    self.statusItem.button.appearsDisabled = !enabled || !engineRunning;
    self.permissionRetryButton.hidden = engineRunning;
    self.privacySettingsButton.hidden = engineRunning;

    self.showIconCheckbox.state = showIcon ? NSControlStateValueOn : NSControlStateValueOff;
    double clickInterval = [self.settingsStore doubleForKey:@"ClickSpeed" defaultValue:0.25];
    self.clickSpeedSlider.doubleValue = 0.5 - clickInterval;
    self.sensitivitySlider.doubleValue = [self.settingsStore doubleForKey:@"Sensitivity" defaultValue:4.6666];
    [self.logLevelPopup selectItemWithTag:[self.settingsStore integerForKey:@"LogLevel" defaultValue:0]];

    self.trackpadCheckbox.state = [self.settingsStore boolForKey:@"enTPAll" defaultValue:YES];
    self.trackpadHandedness.selectedSegment = [self.settingsStore integerForKey:@"Handed" defaultValue:0];
    self.nativeDragProtectionCheckbox.state =
        [self.settingsStore boolForKey:JTNativeThreeFingerDragProtectionKey defaultValue:YES]
            ? NSControlStateValueOn
            : NSControlStateValueOff;
    self.mouseCheckbox.state = [self.settingsStore boolForKey:@"enMMAll" defaultValue:YES];
    self.mouseHandedness.selectedSegment = [self.settingsStore integerForKey:@"MMHanded" defaultValue:0];
    self.recognitionTrackpadCheckbox.state = [self.settingsStore boolForKey:@"enCharRegTP" defaultValue:NO];
    self.recognitionMouseCheckbox.state = [self.settingsStore boolForKey:@"enCharRegMM" defaultValue:NO];

    self.clickSpeedSlider.enabled = enabled;
    self.sensitivitySlider.enabled = enabled;
    self.trackpadCheckbox.enabled = enabled;
    self.trackpadHandedness.enabled = enabled && self.trackpadCheckbox.state == NSControlStateValueOn;
    self.nativeDragProtectionCheckbox.enabled =
        enabled && self.trackpadCheckbox.state == NSControlStateValueOn;
    self.mouseCheckbox.enabled = enabled;
    self.mouseHandedness.enabled = enabled && self.mouseCheckbox.state == NSControlStateValueOn;
    self.recognitionTrackpadCheckbox.enabled = enabled;
    self.recognitionMouseCheckbox.enabled = enabled;
}

- (void)applyStatusItemVisibility:(BOOL)visible {
    if (visible) {
        [self buildStatusItem];
    } else if (self.statusItem != nil) {
        [[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
        self.statusItem = nil;
        self.enabledMenuItem = nil;
    }
}

@end
