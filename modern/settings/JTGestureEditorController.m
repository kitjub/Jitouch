#import "JTGestureEditorController.h"

#import <ApplicationServices/ApplicationServices.h>

#import "JTSettingsStore.h"
#import "JTShortcutRecorderField.h"
#import "JTThreeFingerGestureSafety.h"

static NSString *const JTEditorApplication = @"Application";
static NSString *const JTEditorPath = @"Path";
static NSString *const JTEditorCommand = @"_Command";

static NSArray<NSString *> *JTBuiltInActions(NSString *commandsKey) {
    NSMutableArray *actions = [@[
        @"-", @"Copy", @"Paste", @"New", @"Open", @"Save", @"New Tab",
        @"Close / Close Tab", @"Quit", @"Hide", @"Minimize", @"Zoom",
        @"Maximize", @"Un-Maximize", @"Maximize Left", @"Maximize Right",
        @"Refresh", @"Next Tab", @"Previous Tab", @"Open Recently Closed Tab",
        @"Full Screen", @"Launch Finder", @"Launch Browser", @"Show Desktop",
        @"Mission Control", @"Application Windows", @"Application Switcher",
        @"Previous Window",
        @"Launchpad", @"Scroll to Top", @"Scroll to Bottom", @"Play / Pause",
        @"Next", @"Previous", @"Volume Up", @"Volume Down", @"Brightness Up",
        @"Brightness Down"
    ] mutableCopy];
    if (![commandsKey isEqualToString:@"RecognitionCommands"]) {
        [actions addObjectsFromArray:@[@"Left Click", @"Right Click", @"Middle Click",
                                       @"Open Link in New Tab", @"Select Tab Above Cursor"]];
    }
    return actions;
}

@interface JTGestureEditorController () <NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic, strong) JTSettingsStore *store;
@property(nonatomic, copy) NSString *commandsKey;
@property(nonatomic, copy) NSString *deviceTitle;
@property(nonatomic, copy) NSArray<NSString *> *gestureCatalog;
@property(nonatomic, copy) NSArray<NSDictionary *> *rows;
@property(nonatomic, strong) NSTableView *tableView;
@property(nonatomic, strong) NSButton *editButton;
@property(nonatomic, strong) NSButton *removeButton;
@end

@implementation JTGestureEditorController

- (BOOL)nativeDragProtectionEnabled {
    return [self.commandsKey isEqualToString:JTTrackpadCommandsKey] &&
           [self.store boolForKey:JTNativeThreeFingerDragProtectionKey defaultValue:YES];
}

- (BOOL)gestureIsBlockedByNativeDragProtection:(NSString *)gesture {
    return [self nativeDragProtectionEnabled] &&
           JTThreeFingerGestureConflictsWithNativeDrag(gesture);
}

- (NSString *)nativeDragConflictMessageForGesture:(NSString *)gesture {
    return [NSString stringWithFormat:
        @"%@ moves or clicks with the same three contacts used by macOS dragging. Native Drag Protection blocks it at both the editor and engine. Three-Finger Tap and Two-Fix Double-Tap remain available.",
        gesture];
}

- (BOOL)gestureRequiresGlobalApplication:(NSString *)gesture {
    if (![self.commandsKey isEqualToString:JTTrackpadCommandsKey]) return NO;
    return [gesture isEqualToString:@"Left-Side Volume Scrub"] ||
           [gesture isEqualToString:@"Right-Side Volume Scrub"];
}

- (NSString *)globalApplicationMessageForGesture:(NSString *)gesture {
    return [NSString stringWithFormat:
        @"%@ is a system-level trackpad control, so it must be assigned to All Applications. This keeps normal scrolling out of per-app Accessibility routing.",
        gesture];
}

- (instancetype)initWithStore:(JTSettingsStore *)store
                   commandsKey:(NSString *)commandsKey
                   deviceTitle:(NSString *)deviceTitle
                gestureCatalog:(NSArray<NSString *> *)gestureCatalog {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _store = store;
        _commandsKey = [commandsKey copy];
        _deviceTitle = [deviceTitle copy];
        _gestureCatalog = [gestureCatalog copy];
        _rows = @[];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(storeDidChange:)
                                                     name:JTSettingsStoreDidChangeNotification
                                                   object:store];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 700, 380)];

    NSTextField *title = [NSTextField labelWithString:
        [NSString stringWithFormat:@"%@ gesture assignments", self.deviceTitle]];
    title.font = [NSFont systemFontOfSize:16 weight:NSFontWeightSemibold];
    title.translatesAutoresizingMaskIntoConstraints = NO;

    self.tableView = [[NSTableView alloc] initWithFrame:NSZeroRect];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.usesAlternatingRowBackgroundColors = YES;
    self.tableView.allowsMultipleSelection = NO;
    self.tableView.target = self;
    self.tableView.doubleAction = @selector(editSelected:);
    for (NSArray *definition in @[
        @[@"Enable", @"On", @54],
        @[@"Application", @"Application", @170],
        @[@"Gesture", @"Gesture", @190],
        @[@"Command", @"Command", @240],
    ]) {
        NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:definition[0]];
        column.title = definition[1];
        column.width = [definition[2] doubleValue];
        [self.tableView addTableColumn:column];
    }
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.documentView = self.tableView;
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSBezelBorder;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;

    NSButton *add = [NSButton buttonWithTitle:@"+" target:self action:@selector(addCommand:)];
    add.toolTip = @"Add assignment";
    self.editButton = [NSButton buttonWithTitle:@"Edit…" target:self action:@selector(editSelected:)];
    self.removeButton = [NSButton buttonWithTitle:@"−" target:self action:@selector(removeSelected:)];
    self.removeButton.toolTip = @"Delete assignment";
    NSStackView *buttons = [NSStackView stackViewWithViews:@[add, self.removeButton, self.editButton]];
    buttons.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttons.spacing = 8;
    buttons.translatesAutoresizingMaskIntoConstraints = NO;

    [root addSubview:title];
    [root addSubview:scroll];
    [root addSubview:buttons];
    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [title.topAnchor constraintEqualToAnchor:root.topAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10],
        [scroll.bottomAnchor constraintEqualToAnchor:buttons.topAnchor constant:-8],
        [buttons.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [buttons.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
    ]];
    self.view = root;
    [self reloadRows];
}

- (void)storeDidChange:(NSNotification *)notification {
    (void)notification;
    [self reloadRows];
}

- (void)reloadRows {
    NSError *error = nil;
    NSArray *applications = [self.store commandsForKey:self.commandsKey error:&error];
    if (applications == nil) {
        [self showStoreError:error];
        return;
    }
    NSMutableArray *rows = [NSMutableArray array];
    for (id applicationValue in applications) {
        if (![applicationValue isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *application = applicationValue;
        NSString *name = [application[@"Application"] isKindOfClass:NSString.class]
            ? application[@"Application"] : @"Unknown Application";
        NSString *path = [application[@"Path"] isKindOfClass:NSString.class] ? application[@"Path"] : @"";
        NSArray *commands = [application[@"Gestures"] isKindOfClass:NSArray.class]
            ? application[@"Gestures"] : @[];
        for (id commandValue in commands) {
            if (![commandValue isKindOfClass:NSDictionary.class]) continue;
            [rows addObject:@{JTEditorApplication:name, JTEditorPath:path, JTEditorCommand:commandValue}];
        }
    }
    self.rows = rows;
    [self.tableView reloadData];
    [self updateButtonState];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    (void)tableView;
    return self.rows.count;
}

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)rowIndex {
    NSDictionary *row = self.rows[rowIndex];
    NSDictionary *command = row[JTEditorCommand];
    if ([tableColumn.identifier isEqualToString:@"Enable"]) {
        NSButton *checkbox = [NSButton checkboxWithTitle:@"" target:self action:@selector(enabledChanged:)];
        checkbox.state = [command[@"Enable"] boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
        checkbox.tag = rowIndex;
        if ([self gestureIsBlockedByNativeDragProtection:command[@"Gesture"]]) {
            checkbox.toolTip = @"Paused by Native Drag Protection. You can turn this assignment off, but cannot enable it while protection is active.";
        } else if ([self gestureRequiresGlobalApplication:command[@"Gesture"]] &&
                   ![row[JTEditorApplication] isEqualToString:@"All Applications"]) {
            checkbox.toolTip = @"This system-level gesture is inactive outside All Applications. Turn it off or replace it with a global assignment.";
        }
        return checkbox;
    }
    NSTextField *field = [NSTextField labelWithString:@""];
    field.lineBreakMode = NSLineBreakByTruncatingTail;
    if ([tableColumn.identifier isEqualToString:@"Application"]) {
        field.stringValue = row[JTEditorApplication];
    } else if ([tableColumn.identifier isEqualToString:@"Gesture"]) {
        NSString *gesture = [command[@"Gesture"] isKindOfClass:NSString.class]
            ? command[@"Gesture"]
            : @"(unknown)";
        if ([self gestureIsBlockedByNativeDragProtection:gesture]) {
            field.stringValue = [NSString stringWithFormat:@"⚠︎ %@ (paused)", gesture];
            field.textColor = NSColor.systemOrangeColor;
        } else if ([self gestureRequiresGlobalApplication:gesture] &&
                   ![row[JTEditorApplication] isEqualToString:@"All Applications"]) {
            field.stringValue = [NSString stringWithFormat:@"⚠︎ %@ (global only)", gesture];
            field.textColor = NSColor.systemOrangeColor;
        } else {
            field.stringValue = gesture;
        }
    } else {
        field.stringValue = [self displayCommand:command];
    }
    return field;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    (void)notification;
    [self updateButtonState];
}

- (void)updateButtonState {
    BOOL selected = self.tableView.selectedRow >= 0 && self.tableView.selectedRow < (NSInteger)self.rows.count;
    self.editButton.enabled = selected;
    self.removeButton.enabled = selected;
}

- (NSString *)displayCommand:(NSDictionary *)command {
    if (![command[@"IsAction"] boolValue]) {
        NSString *legacyName = [command[@"Command"] isKindOfClass:NSString.class] ? command[@"Command"] : nil;
        if (legacyName.length > 0) return legacyName;
        NSUInteger flags = [command[@"ModifierFlags"] unsignedIntegerValue];
        NSMutableString *description = [NSMutableString string];
        if (flags & kCGEventFlagMaskControl) [description appendString:@"⌃"];
        if (flags & kCGEventFlagMaskAlternate) [description appendString:@"⌥"];
        if (flags & kCGEventFlagMaskShift) [description appendString:@"⇧"];
        if (flags & kCGEventFlagMaskCommand) [description appendString:@"⌘"];
        [description appendFormat:@"Key %@", command[@"KeyCode"] ?: @0];
        return description;
    }
    if ([command[@"OpenFilePath"] isKindOfClass:NSString.class]) {
        return [NSString stringWithFormat:@"Open File: %@", [command[@"OpenFilePath"] lastPathComponent]];
    }
    if ([command[@"OpenURL"] isKindOfClass:NSString.class]) {
        return [NSString stringWithFormat:@"Open Website: %@", command[@"OpenURL"]];
    }
    return [command[@"Command"] isKindOfClass:NSString.class] ? command[@"Command"] : @"(unknown)";
}

- (void)addCommand:(id)sender {
    (void)sender;
    [self presentEditorForRow:nil];
}

- (void)editSelected:(id)sender {
    (void)sender;
    NSInteger selected = self.tableView.selectedRow;
    if (selected < 0 || selected >= (NSInteger)self.rows.count) return;
    [self presentEditorForRow:self.rows[selected]];
}

- (void)removeSelected:(id)sender {
    (void)sender;
    NSInteger selected = self.tableView.selectedRow;
    if (selected < 0 || selected >= (NSInteger)self.rows.count) return;
    NSDictionary *row = self.rows[selected];
    NSDictionary *command = row[JTEditorCommand];
    NSAlert *confirm = [[NSAlert alloc] init];
    confirm.messageText = @"Delete this gesture assignment?";
    confirm.informativeText = [NSString stringWithFormat:@"%@ — %@",
        row[JTEditorApplication], command[@"Gesture"] ?: @"Unknown gesture"];
    [confirm addButtonWithTitle:@"Delete"];
    [confirm addButtonWithTitle:@"Cancel"];
    if ([confirm runModal] != NSAlertFirstButtonReturn) return;
    NSError *error = nil;
    if (![self.store removeCommandForApplication:row[JTEditorApplication]
                                         gesture:command[@"Gesture"]
                                          forKey:self.commandsKey
                                           error:&error]) {
        [self showStoreError:error];
    }
}

- (void)enabledChanged:(NSButton *)sender {
    if (sender.tag < 0 || sender.tag >= (NSInteger)self.rows.count) return;
    NSDictionary *row = self.rows[sender.tag];
    NSDictionary *command = row[JTEditorCommand];
    if (sender.state == NSControlStateValueOn &&
        [self gestureIsBlockedByNativeDragProtection:command[@"Gesture"]]) {
        sender.state = NSControlStateValueOff;
        [self presentMessage:[self nativeDragConflictMessageForGesture:command[@"Gesture"]]];
        return;
    }
    if (sender.state == NSControlStateValueOn &&
        [self gestureRequiresGlobalApplication:command[@"Gesture"]] &&
        ![row[JTEditorApplication] isEqualToString:@"All Applications"]) {
        sender.state = NSControlStateValueOff;
        [self presentMessage:[self globalApplicationMessageForGesture:command[@"Gesture"]]];
        return;
    }
    NSError *error = nil;
    if (![self.store setCommandEnabled:sender.state == NSControlStateValueOn
                         forApplication:row[JTEditorApplication]
                                 gesture:command[@"Gesture"]
                                  forKey:self.commandsKey
                                   error:&error]) {
        sender.state = sender.state == NSControlStateValueOn ? NSControlStateValueOff : NSControlStateValueOn;
        [self showStoreError:error];
    }
}

- (NSPopUpButton *)applicationPopupForRow:(nullable NSDictionary *)row {
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [popup addItemWithTitle:@"All Applications"];
    popup.lastItem.representedObject = @{JTEditorApplication:@"All Applications", JTEditorPath:@""};
    NSMutableArray<NSDictionary *> *applications = [NSMutableArray array];
    NSMutableSet *paths = [NSMutableSet set];
    NSArray<NSURL *> *roots = @[
        [NSURL fileURLWithPath:@"/Applications" isDirectory:YES],
        [NSURL fileURLWithPath:@"/System/Applications" isDirectory:YES],
        [NSURL fileURLWithPath:[@"~/Applications" stringByExpandingTildeInPath] isDirectory:YES],
    ];
    NSArray *keys = @[NSURLIsApplicationKey, NSURLNameKey];
    for (NSURL *root in roots) {
        NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager]
            enumeratorAtURL:root includingPropertiesForKeys:keys
                    options:NSDirectoryEnumerationSkipsHiddenFiles |
                            NSDirectoryEnumerationSkipsPackageDescendants
               errorHandler:nil];
        for (NSURL *url in enumerator) {
            NSNumber *isApplication = nil;
            [url getResourceValue:&isApplication forKey:NSURLIsApplicationKey error:nil];
            if (!isApplication.boolValue || [paths containsObject:url.path]) continue;
            [paths addObject:url.path];
            NSBundle *bundle = [NSBundle bundleWithURL:url];
            NSString *name = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?:
                             [bundle objectForInfoDictionaryKey:@"CFBundleName"] ?:
                             url.URLByDeletingPathExtension.lastPathComponent;
            if (name.length > 0) [applications addObject:@{JTEditorApplication:name, JTEditorPath:url.path}];
        }
    }
    [applications sortUsingComparator:^NSComparisonResult(NSDictionary *left, NSDictionary *right) {
        return [left[JTEditorApplication] localizedCaseInsensitiveCompare:right[JTEditorApplication]];
    }];
    for (NSDictionary *application in applications) {
        [popup addItemWithTitle:application[JTEditorApplication]];
        popup.lastItem.representedObject = application;
    }
    for (NSDictionary *existingRow in self.rows) {
        NSString *name = existingRow[JTEditorApplication];
        if (name.length == 0 || [popup indexOfItemWithTitle:name] >= 0) continue;
        [popup addItemWithTitle:name];
        popup.lastItem.representedObject = @{JTEditorApplication:name,
                                             JTEditorPath:existingRow[JTEditorPath] ?: @""};
    }
    if (row != nil) {
        NSString *currentName = row[JTEditorApplication];
        NSString *currentPath = row[JTEditorPath];
        NSInteger found = [popup indexOfItemWithTitle:currentName];
        if (found < 0) {
            [popup addItemWithTitle:currentName];
            popup.lastItem.representedObject = @{JTEditorApplication:currentName, JTEditorPath:currentPath ?: @""};
            found = popup.numberOfItems - 1;
        }
        [popup selectItemAtIndex:found];
    }
    [popup.menu addItem:[NSMenuItem separatorItem]];
    [popup addItemWithTitle:@"Other App…"];
    popup.lastItem.representedObject = [NSNull null];
    return popup;
}

- (void)presentEditorForRow:(nullable NSDictionary *)row {
    NSDictionary *oldCommand = row[JTEditorCommand];
    NSPopUpButton *applicationPopup = [self applicationPopupForRow:row];
    if (row != nil) applicationPopup.enabled = NO;

    NSPopUpButton *gesturePopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    for (NSString *gesture in self.gestureCatalog) [gesturePopup addItemWithTitle:gesture];
    NSString *oldGesture = [oldCommand[@"Gesture"] isKindOfClass:NSString.class] ? oldCommand[@"Gesture"] : nil;
    if (oldGesture.length > 0 && [gesturePopup indexOfItemWithTitle:oldGesture] < 0) {
        [gesturePopup addItemWithTitle:oldGesture];
    }
    if (oldGesture.length > 0) [gesturePopup selectItemWithTitle:oldGesture];

    NSArray *builtIns = JTBuiltInActions(self.commandsKey);
    NSPopUpButton *typePopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    for (NSString *action in builtIns) {
        [typePopup addItemWithTitle:action];
        typePopup.lastItem.representedObject = @"action";
    }
    [typePopup.menu addItem:[NSMenuItem separatorItem]];
    for (NSArray *special in @[@[@"Keyboard Shortcut…", @"shortcut"],
                                @[@"Open File…", @"file"],
                                @[@"Open Website…", @"url"]]) {
        [typePopup addItemWithTitle:special[0]];
        typePopup.lastItem.representedObject = special[1];
    }

    NSString *oldCommandName = [oldCommand[@"Command"] isKindOfClass:NSString.class] ? oldCommand[@"Command"] : @"-";
    if (oldCommand != nil && ![oldCommand[@"IsAction"] boolValue]) {
        [typePopup selectItemWithTitle:@"Keyboard Shortcut…"];
    } else if ([oldCommand[@"OpenFilePath"] isKindOfClass:NSString.class]) {
        [typePopup selectItemWithTitle:@"Open File…"];
    } else if ([oldCommand[@"OpenURL"] isKindOfClass:NSString.class]) {
        [typePopup selectItemWithTitle:@"Open Website…"];
    } else {
        if ([typePopup indexOfItemWithTitle:oldCommandName] < 0) {
            [typePopup insertItemWithTitle:oldCommandName atIndex:builtIns.count];
            [typePopup itemAtIndex:builtIns.count].representedObject = @"action";
        }
        [typePopup selectItemWithTitle:oldCommandName];
    }

    NSString *requiredAction = [self requiredActionForGesture:oldGesture];
    if (requiredAction != nil) {
        if ([typePopup indexOfItemWithTitle:requiredAction] < 0) {
            [typePopup insertItemWithTitle:requiredAction atIndex:0];
            [typePopup itemAtIndex:0].representedObject = @"action";
        }
        [typePopup selectItemWithTitle:requiredAction];
        typePopup.enabled = NO;
        gesturePopup.enabled = NO;
    }

    JTShortcutRecorderField *shortcut = [[JTShortcutRecorderField alloc] initWithFrame:NSZeroRect];
    BOOL oldWasShortcut = oldCommand != nil && ![oldCommand[@"IsAction"] boolValue];
    if (oldWasShortcut) {
        [shortcut setModifierFlags:[oldCommand[@"ModifierFlags"] unsignedIntegerValue]
                           keyCode:(CGKeyCode)[oldCommand[@"KeyCode"] unsignedIntValue]];
    } else {
        [shortcut clearShortcut];
    }
    /*
     * Recording a key combination is an unambiguous choice of command kind.
     * Apply that intent immediately, while still allowing the person to choose
     * a built-in action afterwards without erasing the recorded shortcut.
     */
    __weak NSPopUpButton *weakTypePopup = typePopup;
    shortcut.recordingHandler = ^(JTShortcutRecorderField *field) {
        (void)field;
        NSPopUpButton *popup = weakTypePopup;
        if (popup.enabled &&
            [popup indexOfItemWithTitle:@"Keyboard Shortcut…"] >= 0) {
            [popup selectItemWithTitle:@"Keyboard Shortcut…"];
        }
    };
    NSTextField *fileField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    fileField.placeholderString = @"Choose a file when saving";
    fileField.stringValue = [oldCommand[@"OpenFilePath"] isKindOfClass:NSString.class] ? oldCommand[@"OpenFilePath"] : @"";
    NSTextField *urlField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    urlField.placeholderString = @"https://example.com";
    urlField.stringValue = [oldCommand[@"OpenURL"] isKindOfClass:NSString.class] ? oldCommand[@"OpenURL"] : @"";
    NSButton *enabled = [NSButton checkboxWithTitle:@"Enabled" target:nil action:nil];
    enabled.state = oldCommand == nil || [oldCommand[@"Enable"] boolValue]
        ? NSControlStateValueOn : NSControlStateValueOff;

    NSStackView *form = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 460, 250)];
    form.orientation = NSUserInterfaceLayoutOrientationVertical;
    form.alignment = NSLayoutAttributeLeading;
    form.spacing = 8;
    for (NSArray *pair in @[
        @[@"Application", applicationPopup], @[@"Gesture", gesturePopup], @[@"Action", typePopup],
        @[@"Shortcut", shortcut], @[@"File", fileField], @[@"Website", urlField]
    ]) {
        NSTextField *label = [NSTextField labelWithString:pair[0]];
        [label.widthAnchor constraintEqualToConstant:80].active = YES;
        NSView *control = pair[1];
        [control.widthAnchor constraintEqualToConstant:350].active = YES;
        NSStackView *line = [NSStackView stackViewWithViews:@[label, control]];
        line.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        line.alignment = NSLayoutAttributeCenterY;
        [form addArrangedSubview:line];
    }
    [form addArrangedSubview:enabled];

    NSAlert *editor = [[NSAlert alloc] init];
    editor.messageText = row == nil ? @"Add gesture assignment" : @"Edit gesture assignment";
    editor.informativeText = [self nativeDragProtectionEnabled]
        ? @"Native Drag Protection is on. Passive three-finger taps remain available; moving or clicking three-finger gestures cannot be enabled. Unknown legacy rows are preserved."
        : @"Unknown legacy rows are preserved. Choose only the field you want to change.";
    editor.accessoryView = form;
    [editor addButtonWithTitle:@"Save"];
    [editor addButtonWithTitle:@"Cancel"];
    if ([editor runModal] != NSAlertFirstButtonReturn) return;

    NSDictionary *selectedApplication = applicationPopup.selectedItem.representedObject;
    if ((id)selectedApplication == [NSNull null]) {
        NSOpenPanel *panel = [NSOpenPanel openPanel];
        panel.canChooseDirectories = NO;
        panel.allowsMultipleSelection = NO;
        panel.prompt = @"Choose App";
        if ([panel runModal] != NSModalResponseOK) return;
        NSURL *url = panel.URL;
        NSBundle *bundle = [NSBundle bundleWithURL:url];
        if (bundle.bundleIdentifier.length == 0) {
            [self presentMessage:@"Choose a macOS application bundle."];
            return;
        }
        NSString *name = [bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?:
                         [bundle objectForInfoDictionaryKey:@"CFBundleName"] ?:
                         url.URLByDeletingPathExtension.lastPathComponent;
        selectedApplication = @{JTEditorApplication:name ?: @"Other Application", JTEditorPath:url.path ?: @""};
    }
    NSString *application = selectedApplication[JTEditorApplication];
    NSString *path = selectedApplication[JTEditorPath] ?: @"";
    NSString *gesture = gesturePopup.selectedItem.title;
    if (gesture.length == 0) {
        [self presentMessage:@"Choose a gesture before saving."];
        return;
    }
    if ([self gestureRequiresGlobalApplication:gesture] &&
        ![application isEqualToString:@"All Applications"]) {
        [self presentMessage:[self globalApplicationMessageForGesture:gesture]];
        return;
    }
    if (enabled.state == NSControlStateValueOn &&
        [self gestureIsBlockedByNativeDragProtection:gesture]) {
        [self presentMessage:[self nativeDragConflictMessageForGesture:gesture]];
        return;
    }
    requiredAction = [self requiredActionForGesture:gesture];
    if (requiredAction != nil) {
        if ([typePopup indexOfItemWithTitle:requiredAction] < 0) {
            [typePopup insertItemWithTitle:requiredAction atIndex:0];
            [typePopup itemAtIndex:0].representedObject = @"action";
        }
        [typePopup selectItemWithTitle:requiredAction];
    }

    NSDictionary *duplicate = [self duplicateForApplication:application gesture:gesture excludingRow:row];
    if (duplicate != nil) {
        NSAlert *replace = [[NSAlert alloc] init];
        replace.messageText = @"Replace the existing assignment?";
        replace.informativeText = [NSString stringWithFormat:@"%@ already has an assignment for %@.", application, gesture];
        [replace addButtonWithTitle:@"Replace"];
        [replace addButtonWithTitle:@"Cancel"];
        if ([replace runModal] != NSAlertFirstButtonReturn) return;
    }

    NSMutableDictionary *command = oldCommand != nil ? [oldCommand mutableCopy] : [NSMutableDictionary dictionary];
    command[@"Gesture"] = gesture;
    command[@"Enable"] = @(enabled.state == NSControlStateValueOn);
    NSString *kind = typePopup.selectedItem.representedObject;
    [command removeObjectForKey:@"OpenFilePath"];
    [command removeObjectForKey:@"OpenURL"];
    if ([kind isEqualToString:@"shortcut"]) {
        if (!oldWasShortcut && !shortcut.hasRecordedShortcut) {
            [self presentMessage:@"Click the shortcut field and press the key combination you want to use."];
            return;
        }
        if (shortcut.keyCode >= 128) {
            [self presentMessage:@"That key cannot be represented by the legacy Jitouch shortcut format."];
            return;
        }
        command[@"Command"] = shortcut.hasRecordedShortcut
            ? shortcut.stringValue
            : (oldCommandName.length > 0 ? oldCommandName : @"Keyboard Shortcut");
        command[@"IsAction"] = @NO;
        command[@"ModifierFlags"] = @(shortcut.modifierFlags);
        command[@"KeyCode"] = @(shortcut.keyCode);
    } else if ([kind isEqualToString:@"file"]) {
        NSString *filePath = fileField.stringValue;
        if (filePath.length == 0) {
            NSOpenPanel *panel = [NSOpenPanel openPanel];
            panel.canChooseDirectories = YES;
            if ([panel runModal] != NSModalResponseOK) return;
            filePath = panel.URL.path;
        }
        command[@"Command"] = @"Open File";
        command[@"IsAction"] = @YES;
        command[@"ModifierFlags"] = @0;
        command[@"KeyCode"] = @0;
        command[@"OpenFilePath"] = filePath;
    } else if ([kind isEqualToString:@"url"]) {
        NSURL *url = [NSURL URLWithString:urlField.stringValue];
        if (url == nil || url.scheme.length == 0) {
            [self presentMessage:@"Enter a complete website address, including https:// or http://."];
            return;
        }
        command[@"Command"] = @"Open Website";
        command[@"IsAction"] = @YES;
        command[@"ModifierFlags"] = @0;
        command[@"KeyCode"] = @0;
        command[@"OpenURL"] = url.absoluteString;
    } else {
        command[@"Command"] = typePopup.selectedItem.title;
        command[@"IsAction"] = @YES;
        command[@"ModifierFlags"] = @0;
        command[@"KeyCode"] = @0;
    }

    NSString *replacingGesture = oldGesture;
    NSError *error = nil;
    BOOL renamedOntoDuplicate = duplicate != nil && row != nil &&
        ![oldGesture isEqualToString:gesture];
    if (renamedOntoDuplicate &&
        ![self.store removeCommandForApplication:application gesture:gesture
                                          forKey:self.commandsKey error:&error]) {
        [self showStoreError:error];
        return;
    }
    if (![self.store upsertCommand:command application:application path:path
                 replacingGesture:replacingGesture forKey:self.commandsKey error:&error]) {
        // The store has no cross-row transaction API. If replacing a duplicate
        // fails after removal, restore its exact dictionary before reporting.
        if (renamedOntoDuplicate) {
            NSDictionary *duplicateCommand = duplicate[JTEditorCommand];
            NSError *rollbackError = nil;
            [self.store upsertCommand:duplicateCommand application:application
                                 path:duplicate[JTEditorPath] ?: path
                    replacingGesture:nil forKey:self.commandsKey error:&rollbackError];
        }
        [self showStoreError:error];
        return;
    }
}

- (nullable NSString *)requiredActionForGesture:(nullable NSString *)gesture {
    if (gesture.length == 0) return nil;
    if ([gesture isEqualToString:@"All Unassigned Gestures"]) return @"-";
    if ([self.commandsKey isEqualToString:@"TrackpadCommands"]) {
        if ([gesture isEqualToString:@"One-Fix One-Slide"]) return @"Move / Resize";
        if ([gesture isEqualToString:@"Left-Side Scroll"] ||
            [gesture isEqualToString:@"Right-Side Scroll"]) return @"Auto Scroll";
        if ([gesture isEqualToString:@"Left-Side Volume Scrub"] ||
            [gesture isEqualToString:@"Right-Side Volume Scrub"]) return @"Volume Scrub";
    }
    if ([self.commandsKey isEqualToString:@"MagicMouseCommands"]) {
        if ([gesture isEqualToString:@"V-Shape"]) return @"Move / Resize";
        if ([gesture isEqualToString:@"Thumb"]) return @"Quick Tab Switching";
    }
    return nil;
}

- (nullable NSDictionary *)duplicateForApplication:(NSString *)application
                                            gesture:(NSString *)gesture
                                       excludingRow:(nullable NSDictionary *)excluded {
    for (NSDictionary *row in self.rows) {
        if (row == excluded) continue;
        NSDictionary *command = row[JTEditorCommand];
        if ([row[JTEditorApplication] isEqualToString:application] &&
            [command[@"Gesture"] isEqualToString:gesture]) return row;
    }
    return nil;
}

- (void)showStoreError:(NSError *)error {
    [self presentMessage:error.localizedDescription ?: @"The gesture assignment could not be saved."];
}

- (void)presentMessage:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Jitouch Settings";
    alert.informativeText = message;
    [alert runModal];
}

@end
