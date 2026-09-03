#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#import "JTSettingsStore.h"

static NSUInteger assertions;

static void Assert(BOOL condition, NSString *message) {
    assertions++;
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

static NSDictionary *Command(NSString *gesture, NSString *command, BOOL enabled) {
    return @{ @"Gesture": gesture, @"Command": command, @"IsAction": @YES,
              @"ModifierFlags": @0, @"KeyCode": @0, @"Enable": @(enabled) };
}

static NSDictionary *Application(NSString *name, NSString *path, NSArray *gestures) {
    return @{ @"Application": name, @"Path": path, @"Gestures": gestures };
}

static void ReplaceDomain(NSString *domain, NSDictionary *settings) {
    CFStringRef appID = (__bridge CFStringRef)domain;
    NSDictionary *old = CFBridgingRelease(CFPreferencesCopyMultiple(NULL, appID,
        kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
    for (NSString *key in old) {
        CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, appID);
    }
    for (NSString *key in settings) {
        CFPreferencesSetAppValue((__bridge CFStringRef)key,
                                 (__bridge CFPropertyListRef)settings[key], appID);
    }
    Assert(CFPreferencesAppSynchronize(appID), @"seed preferences synchronize");
}

int main(void) {
    @autoreleasepool {
        NSString *domain = [@"com.jitouch.Jitouch.StoreTests." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSURL *temporaryRoot = [NSURL fileURLWithPath:[NSTemporaryDirectory()
            stringByAppendingPathComponent:[@"JitouchStoreTests-" stringByAppendingString:NSUUID.UUID.UUIDString]]
                                          isDirectory:YES];
        NSURL *backupDirectory = [temporaryRoot URLByAppendingPathComponent:@"Backups" isDirectory:YES];

        NSDictionary *seed = @{
            @"enAll": @1,
            JTTrackpadCommandsKey: @[Application(@"All Applications", @"", @[Command(@"Old", @"Previous Tab", YES)])],
            JTMagicMouseCommandsKey: @[Application(@"All Applications", @"", @[Command(@"Middle", @"Middle Click", YES)])],
            JTRecognitionCommandsKey: @[],
        };
        ReplaceDomain(domain, seed);
        JTSettingsStore *store = [[JTSettingsStore alloc] initWithPreferencesAppID:domain
                                                               backupDirectoryURL:backupDirectory];

        __block NSDictionary *lastNotificationSettings = nil;
        id observer = [[NSNotificationCenter defaultCenter]
            addObserverForName:JTSettingsStoreDidChangeNotification
                        object:store
                         queue:nil
                    usingBlock:^(NSNotification *note) {
                        lastNotificationSettings = note.userInfo;
                    }];

        NSError *error = nil;
        NSArray *trackpad = [store commandsForKey:JTTrackpadCommandsKey error:&error];
        Assert(trackpad.count == 1 && error == nil, @"safe command lookup");
        BOOL immutable = NO;
        @try { [(NSMutableArray *)trackpad addObject:@{}]; }
        @catch (NSException *exception) { immutable = YES; }
        Assert(immutable, @"lookup returns immutable detached snapshot");

        NSDictionary *before = store.allSettings;
        Assert([store upsertCommand:Command(@"New", @"Next Tab", YES)
                         application:@"All Applications"
                                path:@"/updated/path"
                    replacingGesture:@"Old"
                              forKey:JTTrackpadCommandsKey
                               error:&error], @"upsert existing command");
        Assert(store.lastBackupURL != nil && [store.lastBackupURL checkResourceIsReachableAndReturnError:nil],
               @"backup created before edit");
        NSDictionary *backup = [NSDictionary dictionaryWithContentsOfURL:store.lastBackupURL];
        Assert([backup isEqual:before], @"backup contains complete pre-change settings");
        Assert([lastNotificationSettings[JTMagicMouseCommandsKey] isEqual:seed[JTMagicMouseCommandsKey]],
               @"change notification contains full untouched settings");
        trackpad = [store commandsForKey:JTTrackpadCommandsKey error:&error];
        Assert([trackpad[0][@"Path"] isEqual:@"/updated/path"], @"upsert explicitly updates existing path");
        Assert([trackpad[0][@"Gestures"][0][@"Gesture"] isEqual:@"New"], @"gesture replaced by name");

        Assert([store upsertCommand:Command(@"Tap", @"Close", YES)
                         application:@"Finder" path:@"/System/Library/CoreServices/Finder.app"
                    replacingGesture:nil forKey:JTTrackpadCommandsKey error:&error],
               @"upsert creates missing application");
        Assert([store upsertCommand:Command(@"Swipe", @"Open", YES)
                         application:@"Finder" path:@"/new/Finder.app"
                    replacingGesture:nil forKey:JTTrackpadCommandsKey error:&error],
               @"upsert matches application by name");
        trackpad = [store commandsForKey:JTTrackpadCommandsKey error:&error];
        Assert(trackpad.count == 2, @"upsert does not duplicate application when path changes");
        Assert([trackpad[1][@"Path"] isEqual:@"/new/Finder.app"] &&
               [trackpad[1][@"Gestures"] count] == 2, @"path updates while gestures are retained");

        NSURL *backupBeforeInvalid = store.lastBackupURL;
        NSDictionary *badKeyCode = @{ @"Gesture": @"Bad", @"Command": @"Bad", @"IsAction": @YES,
                                      @"ModifierFlags": @0, @"KeyCode": @128, @"Enable": @1 };
        error = nil;
        Assert(![store upsertCommand:badKeyCode application:@"Finder" path:@""
                    replacingGesture:nil forKey:JTTrackpadCommandsKey error:&error] &&
               error.code == JTSettingsStoreErrorInvalidStructure,
               @"out-of-range key code rejected");
        Assert([store.lastBackupURL isEqual:backupBeforeInvalid], @"invalid edit creates no backup");

        error = nil;
        Assert(![store addCommandApplication:Application(@"Finder", @"/duplicate", @[])
                                      toCollection:JTCommandCollectionTrackpad error:&error] &&
               error.code == JTSettingsStoreErrorDuplicateApplication,
               @"duplicate application name rejected");

        Assert([store setCommandEnabled:NO forApplication:@"Finder" gesture:@"Tap"
                                  forKey:JTTrackpadCommandsKey error:&error], @"enable state edit");
        trackpad = [store commandsForKey:JTTrackpadCommandsKey error:&error];
        Assert(![trackpad[1][@"Gestures"][0][@"Enable"] boolValue], @"enable state persisted");
        Assert([store removeCommandForApplication:@"Finder" gesture:@"Swipe"
                                           forKey:JTTrackpadCommandsKey error:&error], @"remove by names");

        NSDictionary *duplicateTree = @{JTTrackpadCommandsKey: @[
            Application(@"Duplicate", @"/one", @[]), Application(@"Duplicate", @"/two", @[])]};
        error = nil;
        Assert([store validateCommandStructureInSettings:duplicateTree error:&error],
               @"whole-tree validation preserves legacy duplicate applications");
        NSDictionary *duplicateGestures = @{JTTrackpadCommandsKey: @[
            Application(@"One App", @"", @[Command(@"Tap", @"One", YES), Command(@"Tap", @"Two", YES)])]};
        error = nil;
        Assert([store validateCommandStructureInSettings:duplicateGestures error:&error],
               @"whole-tree validation preserves legacy duplicate gestures");

        NSUInteger beforeAppCRUD = [[store commandApplicationsForCollection:JTCommandCollectionRecognition error:&error] count];
        Assert([store addCommandApplication:Application(@"Draw App", @"", @[])
                                      toCollection:JTCommandCollectionRecognition error:&error], @"add application by index API");
        Assert([store addGestureCommand:Command(@"B", @"Browser", YES) toApplicationAtIndex:beforeAppCRUD
                              collection:JTCommandCollectionRecognition error:&error], @"add nested gesture");
        Assert([store updateGestureCommandAtIndex:0 applicationIndex:beforeAppCRUD
                                      withCommand:Command(@"F", @"Finder", YES)
                                       collection:JTCommandCollectionRecognition error:&error], @"update nested gesture");
        Assert([store removeGestureCommandAtIndex:0 applicationIndex:beforeAppCRUD
                                        collection:JTCommandCollectionRecognition error:&error], @"remove nested gesture");
        Assert([store removeCommandApplicationAtIndex:beforeAppCRUD collection:JTCommandCollectionRecognition error:&error],
               @"remove application by index API");

        ReplaceDomain(domain, duplicateTree);
        NSArray *legacyDuplicates = [store commandsForKey:JTTrackpadCommandsKey error:&error];
        Assert(legacyDuplicates.count == 2, @"lookup preserves legacy duplicate applications");
        NSDictionary *duplicatesBefore = store.allSettings;
        error = nil;
        Assert(![store upsertCommand:Command(@"Tap", @"No-op", YES)
                              application:@"Duplicate" path:@"/new"
                         replacingGesture:nil forKey:JTTrackpadCommandsKey error:&error] &&
               error.code == JTSettingsStoreErrorDuplicateApplication,
               @"ambiguous name-based edit rejects legacy duplicate applications");
        Assert([store.allSettings isEqual:duplicatesBefore], @"ambiguous edit does not rewrite or merge legacy data");

        [[NSNotificationCenter defaultCenter] removeObserver:observer];
        ReplaceDomain(domain, @{});
        NSError *removeError = nil;
        [[NSFileManager defaultManager] removeItemAtURL:temporaryRoot error:&removeError];
        Assert(removeError == nil, @"temporary test backups removed");
        NSLog(@"PASS: %lu settings-store assertions", (unsigned long)assertions);
    }
    return 0;
}
