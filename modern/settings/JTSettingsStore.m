#import "JTSettingsStore.h"

#import <CoreFoundation/CoreFoundation.h>

NSNotificationName const JTSettingsStoreDidChangeNotification = @"JTSettingsStoreDidChangeNotification";
NSErrorDomain const JTSettingsStoreErrorDomain = @"JTSettingsStoreErrorDomain";
NSString *const JTTrackpadCommandsKey = @"TrackpadCommands";
NSString *const JTMagicMouseCommandsKey = @"MagicMouseCommands";
NSString *const JTRecognitionCommandsKey = @"RecognitionCommands";
NSString *const JTNativeThreeFingerDragProtectionKey = @"NativeThreeFingerDragProtection";

static CFStringRef const JTPreferencesAppID = CFSTR("com.jitouch.Jitouch");
static NSString *const JTEnabledKey = @"enAll";

// These names and objects are part of the protocol used by the existing engine.
static NSString *const JTSettingsToEngineNotification = @"My Notification";
static NSString *const JTSettingsToEngineObject = @"com.jitouch.Jitouch.PrefpaneTarget";
static NSString *const JTEngineToSettingsNotification = @"My Notification2";
static NSString *const JTEngineToSettingsObject = @"com.jitouch.Jitouch.PrefpaneTarget2";

@interface JTSettingsStore ()
@property(nonatomic) BOOL cachedEnabled;
@property(nonatomic, copy) NSString *preferencesAppID;
@property(nonatomic, strong) NSURL *backupDirectoryURL;
@property(nonatomic, readwrite, nullable) NSURL *lastBackupURL;
@property(nonatomic) BOOL usesLegacyEngineProtocol;
@end

@implementation JTSettingsStore

- (instancetype)init {
    NSURL *applicationSupport = [[[NSFileManager defaultManager]
        URLsForDirectory:NSApplicationSupportDirectory
               inDomains:NSUserDomainMask] firstObject];
    NSURL *backupDirectory = [[applicationSupport URLByAppendingPathComponent:@"Jitouch Modern"
                                                                  isDirectory:YES]
        URLByAppendingPathComponent:@"Preference Backups" isDirectory:YES];
    return [self initWithPreferencesAppID:(__bridge NSString *)JTPreferencesAppID
                       backupDirectoryURL:backupDirectory];
}

- (instancetype)initWithPreferencesAppID:(NSString *)preferencesAppID
                       backupDirectoryURL:(NSURL *)backupDirectoryURL {
    self = [super init];
    if (self) {
        _preferencesAppID = [preferencesAppID copy];
        _backupDirectoryURL = backupDirectoryURL;
        _usesLegacyEngineProtocol = [preferencesAppID isEqualToString:(__bridge NSString *)JTPreferencesAppID];
        [self reload];
        if (_usesLegacyEngineProtocol) {
            [[NSDistributedNotificationCenter defaultCenter]
                addObserver:self
                   selector:@selector(engineSettingsDidChange:)
                       name:JTEngineToSettingsNotification
                     object:JTEngineToSettingsObject];
        }
    }
    return self;
}

- (void)dealloc {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)isEnabled {
    return self.cachedEnabled;
}

- (void)setEnabled:(BOOL)enabled {
    self.cachedEnabled = enabled;
    [self setBool:enabled forKey:JTEnabledKey];
}

- (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)defaultValue {
    id value = [self allSettings][key];
    return value == nil ? defaultValue : [value boolValue];
}

- (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)defaultValue {
    id value = [self allSettings][key];
    return value == nil ? defaultValue : [value integerValue];
}

- (double)doubleForKey:(NSString *)key defaultValue:(double)defaultValue {
    id value = [self allSettings][key];
    return value == nil ? defaultValue : [value doubleValue];
}

- (void)setBool:(BOOL)value forKey:(NSString *)key {
    [self setInteger:value ? 1 : 0 forKey:key];
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)key {
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberNSIntegerType, &value);
    [self setPreferenceValue:number forKey:key];
    CFRelease(number);
}

- (void)setDouble:(double)value forKey:(NSString *)key {
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberDoubleType, &value);
    [self setPreferenceValue:number forKey:key];
    CFRelease(number);
}

- (void)setPreferenceValue:(CFPropertyListRef)value forKey:(NSString *)key {
    CFStringRef appID = (__bridge CFStringRef)self.preferencesAppID;
    CFPreferencesSetAppValue((__bridge CFStringRef)key, value, appID);
    CFPreferencesAppSynchronize(appID);

    [self publishSettings:[self allSettings]];
}

- (void)publishSettings:(NSDictionary<NSString *, id> *)settings {
    self.cachedEnabled = settings[JTEnabledKey] == nil ? YES : [settings[JTEnabledKey] boolValue];

    // The old engine replaces its in-memory settings dictionary from userInfo,
    // so send the complete domain rather than only the changed value.
    if (self.usesLegacyEngineProtocol) {
        [[NSDistributedNotificationCenter defaultCenter]
            postNotificationName:JTSettingsToEngineNotification
                          object:JTSettingsToEngineObject
                        userInfo:settings
              deliverImmediately:YES];
    }
    [[NSNotificationCenter defaultCenter]
        postNotificationName:JTSettingsStoreDidChangeNotification
                      object:self
                    userInfo:settings];
}

- (NSDictionary<NSString *, id> *)allSettings {
    CFStringRef appID = (__bridge CFStringRef)self.preferencesAppID;
    CFDictionaryRef values = CFPreferencesCopyMultiple(NULL,
                                                       appID,
                                                       kCFPreferencesCurrentUser,
                                                       kCFPreferencesAnyHost);
    NSDictionary *settings = CFBridgingRelease(values);
    return settings ?: @{};
}

static NSString *JTKeyForCollection(JTCommandCollection collection) {
    switch (collection) {
        case JTCommandCollectionTrackpad: return JTTrackpadCommandsKey;
        case JTCommandCollectionMagicMouse: return JTMagicMouseCommandsKey;
        case JTCommandCollectionRecognition: return JTRecognitionCommandsKey;
    }
    return nil;
}

static BOOL JTCollectionForKey(NSString *key, JTCommandCollection *collection) {
    if ([key isEqualToString:JTTrackpadCommandsKey]) {
        *collection = JTCommandCollectionTrackpad;
    } else if ([key isEqualToString:JTMagicMouseCommandsKey]) {
        *collection = JTCommandCollectionMagicMouse;
    } else if ([key isEqualToString:JTRecognitionCommandsKey]) {
        *collection = JTCommandCollectionRecognition;
    } else {
        return NO;
    }
    return YES;
}

- (BOOL)failWithCode:(JTSettingsStoreError)code
          description:(NSString *)description
                error:(NSError **)error {
    if (error != NULL) {
        *error = [NSError errorWithDomain:JTSettingsStoreErrorDomain
                                     code:code
                                 userInfo:@{NSLocalizedDescriptionKey: description}];
    }
    return NO;
}

- (id)detachedPropertyList:(id)value mutable:(BOOL)mutable error:(NSError **)error {
    NSError *serializationError = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:value
                                                               format:NSPropertyListBinaryFormat_v1_0
                                                              options:0
                                                                error:&serializationError];
    if (data == nil) {
        [self failWithCode:JTSettingsStoreErrorInvalidStructure
               description:serializationError.localizedDescription ?: @"Settings are not a valid property list."
                     error:error];
        return nil;
    }
    NSPropertyListReadOptions options = mutable ? NSPropertyListMutableContainersAndLeaves : 0;
    return [NSPropertyListSerialization propertyListWithData:data
                                                     options:options
                                                      format:NULL
                                                       error:error];
}

- (BOOL)validateGestureCommand:(id)value path:(NSString *)path error:(NSError **)error {
    if (![value isKindOfClass:NSDictionary.class]) {
        return [self failWithCode:JTSettingsStoreErrorInvalidStructure
                      description:[NSString stringWithFormat:@"%@ must be a dictionary.", path]
                            error:error];
    }
    NSDictionary *command = value;
    for (NSString *key in @[@"Gesture", @"Command"]) {
        id field = command[key];
        if (![field isKindOfClass:NSString.class] || [field length] == 0) {
            return [self failWithCode:JTSettingsStoreErrorInvalidStructure
                          description:[NSString stringWithFormat:@"%@.%@ must be a non-empty string.", path, key]
                                error:error];
        }
    }
    for (NSString *key in @[@"IsAction", @"ModifierFlags", @"KeyCode", @"Enable"]) {
        if (![command[key] isKindOfClass:NSNumber.class]) {
            return [self failWithCode:JTSettingsStoreErrorInvalidStructure
                          description:[NSString stringWithFormat:@"%@.%@ must be a number.", path, key]
                                error:error];
        }
    }
    NSInteger keyCode = [command[@"KeyCode"] integerValue];
    if (keyCode < 0 || keyCode > 127) {
        return [self failWithCode:JTSettingsStoreErrorInvalidStructure
                      description:[NSString stringWithFormat:@"%@.KeyCode must be between 0 and 127.", path]
                            error:error];
    }
    return YES;
}

- (BOOL)validateCommandApplication:(id)value path:(NSString *)path error:(NSError **)error {
    if (![value isKindOfClass:NSDictionary.class]) {
        return [self failWithCode:JTSettingsStoreErrorInvalidStructure
                      description:[NSString stringWithFormat:@"%@ must be a dictionary.", path]
                            error:error];
    }
    NSDictionary *application = value;
    if (![application[@"Application"] isKindOfClass:NSString.class] ||
        [application[@"Application"] length] == 0 ||
        ![application[@"Path"] isKindOfClass:NSString.class] ||
        ![application[@"Gestures"] isKindOfClass:NSArray.class]) {
        return [self failWithCode:JTSettingsStoreErrorInvalidStructure
                      description:[NSString stringWithFormat:@"%@ requires Application, Path, and Gestures fields.", path]
                            error:error];
    }
    NSArray *gestures = application[@"Gestures"];
    for (NSUInteger index = 0; index < gestures.count; index++) {
        if (![self validateGestureCommand:gestures[index]
                                     path:[NSString stringWithFormat:@"%@.Gestures[%lu]", path, (unsigned long)index]
                                    error:error]) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)validateCommandStructureInSettings:(NSDictionary<NSString *,id> *)candidate
                                     error:(NSError **)error {
    if (![candidate isKindOfClass:NSDictionary.class]) {
        return [self failWithCode:JTSettingsStoreErrorInvalidStructure
                      description:@"The settings root must be a dictionary."
                            error:error];
    }
    for (NSString *key in @[JTTrackpadCommandsKey, JTMagicMouseCommandsKey, JTRecognitionCommandsKey]) {
        id applications = candidate[key];
        if (applications == nil) continue;
        if (![applications isKindOfClass:NSArray.class]) {
            return [self failWithCode:JTSettingsStoreErrorInvalidStructure
                          description:[NSString stringWithFormat:@"%@ must be an array.", key]
                                error:error];
        }
        for (NSUInteger index = 0; index < [applications count]; index++) {
            if (![self validateCommandApplication:applications[index]
                                             path:[NSString stringWithFormat:@"%@[%lu]", key, (unsigned long)index]
                                            error:error]) {
                return NO;
            }
        }
    }
    return YES;
}

- (BOOL)findUniqueApplicationNamed:(NSString *)applicationName
                      applications:(NSArray *)applications
                              index:(NSUInteger *)resultIndex
                              error:(NSError **)error {
    NSUInteger foundIndex = NSNotFound;
    for (NSUInteger index = 0; index < applications.count; index++) {
        if (![applications[index][@"Application"] isEqualToString:applicationName]) continue;
        if (foundIndex != NSNotFound) {
            return [self failWithCode:JTSettingsStoreErrorDuplicateApplication
                          description:@"Multiple legacy application entries have that name; edit by index or resolve them explicitly."
                                error:error];
        }
        foundIndex = index;
    }
    *resultIndex = foundIndex;
    return YES;
}

- (BOOL)findUniqueGestureNamed:(NSString *)gestureName
                       gestures:(NSArray *)gestures
                          index:(NSUInteger *)resultIndex
                          error:(NSError **)error {
    NSUInteger foundIndex = NSNotFound;
    for (NSUInteger index = 0; index < gestures.count; index++) {
        if (![gestures[index][@"Gesture"] isEqualToString:gestureName]) continue;
        if (foundIndex != NSNotFound) {
            return [self failWithCode:JTSettingsStoreErrorDuplicateGesture
                          description:@"Multiple legacy gesture entries have that name; edit by index or resolve them explicitly."
                                error:error];
        }
        foundIndex = index;
    }
    *resultIndex = foundIndex;
    return YES;
}

- (NSArray<NSDictionary<NSString *,id> *> *)commandsForKey:(NSString *)key
                                                      error:(NSError **)error {
    JTCommandCollection collection;
    if (!JTCollectionForKey(key, &collection)) {
        [self failWithCode:JTSettingsStoreErrorInvalidCollection description:@"Unknown command collection key." error:error];
        return nil;
    }
    return [self commandApplicationsForCollection:collection error:error];
}

- (NSArray<NSDictionary<NSString *,id> *> *)commandApplicationsForCollection:(JTCommandCollection)collection
                                                                         error:(NSError **)error {
    NSString *key = JTKeyForCollection(collection);
    if (key == nil) {
        [self failWithCode:JTSettingsStoreErrorInvalidCollection description:@"Unknown command collection." error:error];
        return nil;
    }
    NSDictionary *settingsSnapshot = [self allSettings];
    if (![self validateCommandStructureInSettings:settingsSnapshot error:error]) return nil;
    NSArray *applications = settingsSnapshot[key] ?: @[];
    return [self detachedPropertyList:applications mutable:NO error:error];
}

- (NSDictionary<NSString *,id> *)gestureCommandAtIndex:(NSUInteger)gestureIndex
                                      applicationIndex:(NSUInteger)applicationIndex
                                             collection:(JTCommandCollection)collection
                                                  error:(NSError **)error {
    NSArray *applications = [self commandApplicationsForCollection:collection error:error];
    if (applications == nil) return nil;
    if (applicationIndex >= applications.count) {
        [self failWithCode:JTSettingsStoreErrorIndexOutOfRange description:@"Application index is out of range." error:error];
        return nil;
    }
    NSArray *gestures = applications[applicationIndex][@"Gestures"];
    if (gestureIndex >= gestures.count) {
        [self failWithCode:JTSettingsStoreErrorIndexOutOfRange description:@"Gesture index is out of range." error:error];
        return nil;
    }
    return gestures[gestureIndex];
}

- (BOOL)writeCommandApplications:(NSArray *)applications
                        collection:(JTCommandCollection)collection
                             error:(NSError **)error {
    NSString *key = JTKeyForCollection(collection);
    if (key == nil) {
        return [self failWithCode:JTSettingsStoreErrorInvalidCollection description:@"Unknown command collection." error:error];
    }
    NSMutableDictionary *candidate = [self detachedPropertyList:[self allSettings] mutable:YES error:error];
    if (candidate == nil) return NO;
    candidate[key] = applications;
    if (![self validateCommandStructureInSettings:candidate error:error]) return NO;

    NSError *directoryError = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:self.backupDirectoryURL
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&directoryError]) {
        return [self failWithCode:JTSettingsStoreErrorBackupFailed
                      description:directoryError.localizedDescription ?: @"Could not create the settings backup directory."
                            error:error];
    }
    NSString *filename = [NSString stringWithFormat:@"com.jitouch.Jitouch-%@-%@.plist",
        @((long long)(NSDate.date.timeIntervalSince1970 * 1000)), NSUUID.UUID.UUIDString];
    NSURL *backupURL = [self.backupDirectoryURL URLByAppendingPathComponent:filename];
    NSError *backupError = nil;
    NSData *backupData = [NSPropertyListSerialization dataWithPropertyList:[self allSettings]
                                                                    format:NSPropertyListXMLFormat_v1_0
                                                                   options:0
                                                                     error:&backupError];
    if (backupData == nil || ![backupData writeToURL:backupURL options:NSDataWritingAtomic error:&backupError]) {
        return [self failWithCode:JTSettingsStoreErrorBackupFailed
                      description:backupError.localizedDescription ?: @"Could not back up settings."
                            error:error];
    }
    self.lastBackupURL = backupURL;

    CFStringRef appID = (__bridge CFStringRef)self.preferencesAppID;
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFArrayRef)applications, appID);
    if (!CFPreferencesAppSynchronize(appID)) {
        return [self failWithCode:JTSettingsStoreErrorWriteFailed description:@"Could not synchronize preferences." error:error];
    }
    [self publishSettings:[self allSettings]];
    return YES;
}

- (BOOL)addCommandApplication:(NSDictionary<NSString *,id> *)application
                  toCollection:(JTCommandCollection)collection
                         error:(NSError **)error {
    if (![self validateCommandApplication:application path:@"Application" error:error]) return NO;
    NSMutableArray *applications = [[self commandApplicationsForCollection:collection error:error] mutableCopy];
    if (applications == nil) return NO;
    for (NSDictionary *existing in applications) {
        if ([existing[@"Application"] isEqualToString:application[@"Application"]]) {
            return [self failWithCode:JTSettingsStoreErrorDuplicateApplication
                          description:@"An application with that name already exists."
                                error:error];
        }
    }
    [applications addObject:application];
    return [self writeCommandApplications:applications collection:collection error:error];
}

- (BOOL)updateCommandApplicationAtIndex:(NSUInteger)applicationIndex
                         withApplication:(NSDictionary<NSString *,id> *)application
                              collection:(JTCommandCollection)collection
                                   error:(NSError **)error {
    if (![self validateCommandApplication:application path:@"Application" error:error]) return NO;
    NSMutableArray *applications = [[self commandApplicationsForCollection:collection error:error] mutableCopy];
    if (applications == nil) return NO;
    if (applicationIndex >= applications.count) {
        return [self failWithCode:JTSettingsStoreErrorIndexOutOfRange description:@"Application index is out of range." error:error];
    }
    for (NSUInteger index = 0; index < applications.count; index++) {
        if (index != applicationIndex &&
            [applications[index][@"Application"] isEqualToString:application[@"Application"]]) {
            return [self failWithCode:JTSettingsStoreErrorDuplicateApplication
                          description:@"An application with that name already exists."
                                error:error];
        }
    }
    applications[applicationIndex] = application;
    return [self writeCommandApplications:applications collection:collection error:error];
}

- (BOOL)removeCommandApplicationAtIndex:(NSUInteger)applicationIndex
                              collection:(JTCommandCollection)collection
                                   error:(NSError **)error {
    NSMutableArray *applications = [[self commandApplicationsForCollection:collection error:error] mutableCopy];
    if (applications == nil) return NO;
    if (applicationIndex >= applications.count) {
        return [self failWithCode:JTSettingsStoreErrorIndexOutOfRange description:@"Application index is out of range." error:error];
    }
    [applications removeObjectAtIndex:applicationIndex];
    return [self writeCommandApplications:applications collection:collection error:error];
}

- (BOOL)addGestureCommand:(NSDictionary<NSString *,id> *)command
      toApplicationAtIndex:(NSUInteger)applicationIndex
                 collection:(JTCommandCollection)collection
                      error:(NSError **)error {
    if (![self validateGestureCommand:command path:@"Gesture" error:error]) return NO;
    NSMutableArray *applications = [[self commandApplicationsForCollection:collection error:error] mutableCopy];
    if (applications == nil) return NO;
    if (applicationIndex >= applications.count) {
        return [self failWithCode:JTSettingsStoreErrorIndexOutOfRange description:@"Application index is out of range." error:error];
    }
    NSMutableDictionary *application = [applications[applicationIndex] mutableCopy];
    NSMutableArray *gestures = [application[@"Gestures"] mutableCopy];
    for (NSDictionary *existing in gestures) {
        if ([existing[@"Gesture"] isEqualToString:command[@"Gesture"]]) {
            return [self failWithCode:JTSettingsStoreErrorDuplicateGesture
                          description:@"A gesture with that name already exists in the application."
                                error:error];
        }
    }
    [gestures addObject:command];
    application[@"Gestures"] = gestures;
    applications[applicationIndex] = application;
    return [self writeCommandApplications:applications collection:collection error:error];
}

- (BOOL)updateGestureCommandAtIndex:(NSUInteger)gestureIndex
                   applicationIndex:(NSUInteger)applicationIndex
                        withCommand:(NSDictionary<NSString *,id> *)command
                         collection:(JTCommandCollection)collection
                              error:(NSError **)error {
    if (![self validateGestureCommand:command path:@"Gesture" error:error]) return NO;
    NSMutableArray *applications = [[self commandApplicationsForCollection:collection error:error] mutableCopy];
    if (applications == nil) return NO;
    if (applicationIndex >= applications.count) {
        return [self failWithCode:JTSettingsStoreErrorIndexOutOfRange description:@"Application index is out of range." error:error];
    }
    NSMutableDictionary *application = [applications[applicationIndex] mutableCopy];
    NSMutableArray *gestures = [application[@"Gestures"] mutableCopy];
    if (gestureIndex >= gestures.count) {
        return [self failWithCode:JTSettingsStoreErrorIndexOutOfRange description:@"Gesture index is out of range." error:error];
    }
    for (NSUInteger index = 0; index < gestures.count; index++) {
        if (index != gestureIndex && [gestures[index][@"Gesture"] isEqualToString:command[@"Gesture"]]) {
            return [self failWithCode:JTSettingsStoreErrorDuplicateGesture
                          description:@"A gesture with that name already exists in the application."
                                error:error];
        }
    }
    gestures[gestureIndex] = command;
    application[@"Gestures"] = gestures;
    applications[applicationIndex] = application;
    return [self writeCommandApplications:applications collection:collection error:error];
}

- (BOOL)removeGestureCommandAtIndex:(NSUInteger)gestureIndex
                    applicationIndex:(NSUInteger)applicationIndex
                         collection:(JTCommandCollection)collection
                              error:(NSError **)error {
    NSMutableArray *applications = [[self commandApplicationsForCollection:collection error:error] mutableCopy];
    if (applications == nil) return NO;
    if (applicationIndex >= applications.count) {
        return [self failWithCode:JTSettingsStoreErrorIndexOutOfRange description:@"Application index is out of range." error:error];
    }
    NSMutableDictionary *application = [applications[applicationIndex] mutableCopy];
    NSMutableArray *gestures = [application[@"Gestures"] mutableCopy];
    if (gestureIndex >= gestures.count) {
        return [self failWithCode:JTSettingsStoreErrorIndexOutOfRange description:@"Gesture index is out of range." error:error];
    }
    [gestures removeObjectAtIndex:gestureIndex];
    application[@"Gestures"] = gestures;
    applications[applicationIndex] = application;
    return [self writeCommandApplications:applications collection:collection error:error];
}

- (BOOL)upsertCommand:(NSDictionary<NSString *,id> *)command
           application:(NSString *)applicationName
                  path:(NSString *)path
      replacingGesture:(NSString *)replacingGesture
                forKey:(NSString *)key
                 error:(NSError **)error {
    JTCommandCollection collection;
    if (!JTCollectionForKey(key, &collection)) {
        return [self failWithCode:JTSettingsStoreErrorInvalidCollection description:@"Unknown command collection key." error:error];
    }
    if (applicationName.length == 0 || path == nil ||
        ![self validateGestureCommand:command path:@"Gesture" error:error]) {
        if (applicationName.length == 0 || path == nil) {
            return [self failWithCode:JTSettingsStoreErrorInvalidStructure
                          description:@"Application must be non-empty and Path must be a string."
                                error:error];
        }
        return NO;
    }
    NSMutableArray *applications = [[self commandApplicationsForCollection:collection error:error] mutableCopy];
    if (applications == nil) return NO;
    NSUInteger applicationIndex = NSNotFound;
    if (![self findUniqueApplicationNamed:applicationName applications:applications
                                    index:&applicationIndex error:error]) return NO;
    if (applicationIndex == NSNotFound) {
        [applications addObject:@{@"Application": applicationName,
                                  @"Path": path,
                                  @"Gestures": @[command]}];
    } else {
        NSMutableDictionary *application = [applications[applicationIndex] mutableCopy];
        application[@"Path"] = path;
        NSMutableArray *gestures = [application[@"Gestures"] mutableCopy];
        NSString *target = replacingGesture ?: command[@"Gesture"];
        NSUInteger gestureIndex = NSNotFound;
        if (![self findUniqueGestureNamed:target gestures:gestures index:&gestureIndex error:error]) return NO;
        if (![target isEqualToString:command[@"Gesture"]]) {
            NSUInteger conflictingIndex = NSNotFound;
            if (![self findUniqueGestureNamed:command[@"Gesture"] gestures:gestures
                                        index:&conflictingIndex error:error]) return NO;
            if (conflictingIndex != NSNotFound && conflictingIndex != gestureIndex) {
                return [self failWithCode:JTSettingsStoreErrorDuplicateGesture
                              description:@"A gesture with the new name already exists in the application."
                                    error:error];
            }
        }
        if (gestureIndex == NSNotFound) {
            [gestures addObject:command];
        } else {
            gestures[gestureIndex] = command;
        }
        application[@"Gestures"] = gestures;
        applications[applicationIndex] = application;
    }
    return [self writeCommandApplications:applications collection:collection error:error];
}

- (BOOL)removeCommandForApplication:(NSString *)applicationName
                             gesture:(NSString *)gestureName
                              forKey:(NSString *)key
                               error:(NSError **)error {
    JTCommandCollection collection;
    if (!JTCollectionForKey(key, &collection)) {
        return [self failWithCode:JTSettingsStoreErrorInvalidCollection description:@"Unknown command collection key." error:error];
    }
    NSMutableArray *applications = [[self commandApplicationsForCollection:collection error:error] mutableCopy];
    if (applications == nil) return NO;
    NSUInteger applicationIndex = NSNotFound;
    if (![self findUniqueApplicationNamed:applicationName applications:applications
                                    index:&applicationIndex error:error]) return NO;
    if (applicationIndex != NSNotFound) {
        NSMutableDictionary *application = [applications[applicationIndex] mutableCopy];
        NSMutableArray *gestures = [application[@"Gestures"] mutableCopy];
        NSUInteger gestureIndex = NSNotFound;
        if (![self findUniqueGestureNamed:gestureName gestures:gestures index:&gestureIndex error:error]) return NO;
        if (gestureIndex != NSNotFound) {
            [gestures removeObjectAtIndex:gestureIndex];
            application[@"Gestures"] = gestures;
            applications[applicationIndex] = application;
            return [self writeCommandApplications:applications collection:collection error:error];
        }
    }
    return [self failWithCode:JTSettingsStoreErrorIndexOutOfRange
                  description:@"The application or gesture does not exist."
                        error:error];
}

- (BOOL)setCommandEnabled:(BOOL)enabled
            forApplication:(NSString *)applicationName
                    gesture:(NSString *)gestureName
                     forKey:(NSString *)key
                      error:(NSError **)error {
    JTCommandCollection collection;
    if (!JTCollectionForKey(key, &collection)) {
        return [self failWithCode:JTSettingsStoreErrorInvalidCollection description:@"Unknown command collection key." error:error];
    }
    NSMutableArray *applications = [[self commandApplicationsForCollection:collection error:error] mutableCopy];
    if (applications == nil) return NO;
    NSUInteger applicationIndex = NSNotFound;
    if (![self findUniqueApplicationNamed:applicationName applications:applications
                                    index:&applicationIndex error:error]) return NO;
    if (applicationIndex != NSNotFound) {
        NSMutableDictionary *application = [applications[applicationIndex] mutableCopy];
        NSMutableArray *gestures = [application[@"Gestures"] mutableCopy];
        NSUInteger gestureIndex = NSNotFound;
        if (![self findUniqueGestureNamed:gestureName gestures:gestures index:&gestureIndex error:error]) return NO;
        if (gestureIndex != NSNotFound) {
            NSMutableDictionary *gesture = [gestures[gestureIndex] mutableCopy];
            gesture[@"Enable"] = @(enabled);
            gestures[gestureIndex] = gesture;
            application[@"Gestures"] = gestures;
            applications[applicationIndex] = application;
            return [self writeCommandApplications:applications collection:collection error:error];
        }
    }
    return [self failWithCode:JTSettingsStoreErrorIndexOutOfRange
                  description:@"The application or gesture does not exist."
                        error:error];
}

- (void)reload {
    CFStringRef appID = (__bridge CFStringRef)self.preferencesAppID;
    CFPreferencesAppSynchronize(appID);
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)JTEnabledKey,
                                                        appID);
    // Match the historical default without overwriting the rest of an existing
    // preferences file. Full first-run defaults remain owned by the engine.
    self.cachedEnabled = value == NULL ? YES : [(__bridge id)value boolValue];
    if (value != NULL) {
        CFRelease(value);
    }
}

- (void)engineSettingsDidChange:(NSNotification *)notification {
    NSNumber *enabled = notification.userInfo[JTEnabledKey];
    BOOL newValue;
    if (enabled != nil) {
        newValue = enabled.boolValue;
    } else {
        [self reload];
        newValue = self.cachedEnabled;
    }

    if (newValue == self.cachedEnabled) {
        return;
    }
    self.cachedEnabled = newValue;
    [[NSNotificationCenter defaultCenter]
        postNotificationName:JTSettingsStoreDidChangeNotification
                      object:self];
}

@end
