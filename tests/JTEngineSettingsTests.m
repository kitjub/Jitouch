#import <Cocoa/Cocoa.h>

#import "Settings.h"

static NSUInteger assertions;

static void Assert(BOOL condition, NSString *message) {
    assertions++;
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSDictionary *CommandWithGesture(NSString *gesture, NSString *name,
                                        BOOL enabled) {
    return @{ @"Gesture": gesture, @"Command": name, @"IsAction": @YES,
              @"ModifierFlags": @0, @"KeyCode": @0,
              @"Enable": @(enabled) };
}

static NSDictionary *Command(NSString *name) {
    return CommandWithGesture(@"Tap", name, YES);
}

static NSDictionary *SettingsFixture(NSString *name, NSNumber *nativeDragProtection) {
    NSDictionary *application = @{ @"Application": @"All Applications", @"Path": @"",
                                    @"Gestures": @[Command(name)] };
    NSMutableDictionary *fixture = [@{
        @"enAll": @1, @"ClickSpeed": @0.25, @"Sensitivity": @4,
        @"LogLevel": @0, @"enTPAll": @1, @"Handed": @0,
        @"enMMAll": @0, @"MMHanded": @0, @"enCharRegTP": @0,
        @"enCharRegMM": @0, @"enOneDrawing": @0, @"enTwoDrawing": @1,
        @"TrackpadCommands": @[application], @"MagicMouseCommands": @[],
        @"RecognitionCommands": @[]
    } mutableCopy];
    if (nativeDragProtection != nil) {
        fixture[@"NativeThreeFingerDragProtection"] = nativeDragProtection;
    }
    return fixture;
}

int main(void) {
    @autoreleasepool {
        NSDictionary *first = SettingsFixture(@"First", @YES);
        NSDictionary *second = SettingsFixture(@"Second", @NO);
        [Settings loadSettings2:first];
        Assert(nativeThreeFingerDragProtection == 1,
               @"native drag protection loads enabled");
        [Settings loadSettings2:second];
        Assert(nativeThreeFingerDragProtection == 0,
               @"native drag protection reloads disabled");
        [Settings loadSettings2:SettingsFixture(@"Legacy", nil)];
        Assert(nativeThreeFingerDragProtection == 1,
               @"legacy settings fail safe to native drag protection");
        [Settings loadSettings2:first];

        NSDictionary *snapshot = [Settings copyCommandForApplication:@"Safari"
                                                               gesture:@"Tap"
                                                           commandsKey:@"TrackpadCommands"
                                                       includeCatchAll:YES];
        Assert([[snapshot objectForKey:@"Command"] isEqualToString:@"First"], @"initial snapshot lookup");
        [snapshot release];

        snapshot = [Settings copyCommandForApplication:nil
                                                gesture:@"Tap"
                                            commandsKey:@"TrackpadCommands"
                                        includeCatchAll:YES];
        Assert([[snapshot objectForKey:@"Command"] isEqualToString:@"First"],
               @"anonymous framework surfaces use All Applications fallback");
        [snapshot release];

        snapshot = [Settings copyCommandForApplication:nil
                                                gesture:@"Tap"
                                            commandsKey:@"TrackpadCommands"
                                        includeCatchAll:NO];
        Assert([[snapshot objectForKey:@"Command"] isEqualToString:@"First"],
               @"anonymous surfaces retain global special-gesture lookup");
        [snapshot release];

        NSDictionary *globalEdge = @{
            @"Application": @"All Applications", @"Path": @"",
            @"Gestures": @[CommandWithGesture(@"Left-Side Volume Scrub",
                                               @"Volume Scrub", YES)]
        };
        NSDictionary *appEdge = @{
            @"Application": @"KakaoTalk", @"Path": @"/Applications/KakaoTalk.app",
            @"Gestures": @[CommandWithGesture(@"Right-Side Volume Scrub",
                                               @"Volume Scrub", YES)]
        };
        NSMutableDictionary *edgeFixture = [SettingsFixture(@"Other", @YES) mutableCopy];
        edgeFixture[@"TrackpadCommands"] = @[globalEdge, appEdge];
        [Settings loadSettings2:edgeFixture];
        Assert([Settings isGlobalTrackpadGesture:@"Left-Side Volume Scrub"
                               enabledForCommand:@"Volume Scrub"],
               @"global system gesture uses its enabled exact command");
        Assert(![Settings isGlobalTrackpadGesture:@"Left-Side Volume Scrub"
                                enabledForCommand:@"Other"],
               @"global system gesture requires the expected command");
        Assert(![Settings isGlobalTrackpadGesture:@"Right-Side Volume Scrub"
                                enabledForCommand:@"Volume Scrub"],
               @"an app-specific mapping cannot enter the global hardware path");
        edgeFixture[@"TrackpadCommands"] = @[@{
            @"Application": @"All Applications", @"Path": @"",
            @"Gestures": @[CommandWithGesture(@"Left-Side Volume Scrub",
                                               @"Volume Scrub", NO)]
        }];
        [Settings loadSettings2:edgeFixture];
        Assert(![Settings isGlobalTrackpadGesture:@"Left-Side Volume Scrub"
                                enabledForCommand:@"Volume Scrub"],
               @"a disabled global system gesture remains inactive");
        [edgeFixture release];
        [Settings loadSettings2:first];

        __block int failures = 0;
        dispatch_group_t group = dispatch_group_create();
        dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0);
        dispatch_group_async(group, queue, ^{
            for (NSUInteger index = 0; index < 2000; index++) {
                [Settings loadSettings2:(index & 1) ? first : second];
            }
        });
        for (NSUInteger reader = 0; reader < 4; reader++) {
            dispatch_group_async(group, queue, ^{
                for (NSUInteger index = 0; index < 10000; index++) {
                    NSDictionary *command = [Settings copyCommandForApplication:@"Safari"
                                                                         gesture:@"Tap"
                                                                     commandsKey:@"TrackpadCommands"
                                                                 includeCatchAll:YES];
                    NSString *name = [command objectForKey:@"Command"];
                    if (![name isEqualToString:@"First"] && ![name isEqualToString:@"Second"]) {
                        __sync_fetch_and_add(&failures, 1);
                    }
                    [command release];
                }
            });
        }
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        dispatch_release(group);
        Assert(failures == 0, @"concurrent live-map reload and retained lookup");
        NSLog(@"PASS: %lu engine-settings assertions", (unsigned long)assertions);
    }
    return 0;
}
