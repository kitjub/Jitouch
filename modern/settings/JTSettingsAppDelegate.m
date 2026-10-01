#import "JTSettingsAppDelegate.h"

#import "JTSettingsStore.h"
#import "../engine/JTEngineController.h"
#import "JitouchModern-Swift.h"

@interface JTSettingsAppDelegate ()
@property(nonatomic, strong) JTSettingsStore *settingsStore;
@property(nonatomic, strong) JTEngineController *engineController;
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenuItem *enabledMenuItem;
@property(nonatomic, strong) NSWindow *settingsWindow;
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

#pragma mark - Actions

- (void)toggleEnabled:(id)sender {
    (void)sender;
    self.settingsStore.enabled = !self.settingsStore.isEnabled;
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

- (void)showSettings:(id)sender {
    (void)sender;
    if (self.settingsWindow == nil) {
        self.settingsWindow = [JTSettingsWindowFactory makeWindowWithStore:self.settingsStore
                                                                    engine:self.engineController];
    }
    [self.settingsStore reload];
    [NSApp activateIgnoringOtherApps:YES];
    [self.settingsWindow makeKeyAndOrderFront:nil];
}

- (void)quit:(id)sender {
    [NSApp terminate:sender];
}

- (void)settingsDidChange:(NSNotification *)notification {
    (void)notification;
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
    self.enabledMenuItem.state = enabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.statusItem.button.appearsDisabled = !enabled || !self.engineController.isRunning;
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
