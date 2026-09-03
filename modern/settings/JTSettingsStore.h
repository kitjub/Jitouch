#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, JTCommandCollection) {
    JTCommandCollectionTrackpad,
    JTCommandCollectionMagicMouse,
    JTCommandCollectionRecognition,
};

FOUNDATION_EXPORT NSErrorDomain const JTSettingsStoreErrorDomain;
FOUNDATION_EXPORT NSString *const JTTrackpadCommandsKey;
FOUNDATION_EXPORT NSString *const JTMagicMouseCommandsKey;
FOUNDATION_EXPORT NSString *const JTRecognitionCommandsKey;
FOUNDATION_EXPORT NSString *const JTNativeThreeFingerDragProtectionKey;

typedef NS_ERROR_ENUM(JTSettingsStoreErrorDomain, JTSettingsStoreError) {
    JTSettingsStoreErrorInvalidCollection = 1,
    JTSettingsStoreErrorInvalidStructure,
    JTSettingsStoreErrorIndexOutOfRange,
    JTSettingsStoreErrorBackupFailed,
    JTSettingsStoreErrorWriteFailed,
    JTSettingsStoreErrorDuplicateApplication,
    JTSettingsStoreErrorDuplicateGesture,
};

/// Reads and writes the preference domain used by every released Jitouch build.
/// Keeping this in a small adapter prevents the settings app's bundle identifier
/// from accidentally creating a second, unrelated preference file.
@interface JTSettingsStore : NSObject

@property(nonatomic, getter=isEnabled) BOOL enabled;
@property(nonatomic, readonly, nullable) NSURL *lastBackupURL;

/// Testing and migration initializer. Production callers should use `init`.
/// A non-legacy preference domain never sends the engine's distributed
/// notification, which keeps isolated CLI tests from changing the live engine.
- (instancetype)initWithPreferencesAppID:(NSString *)preferencesAppID
                       backupDirectoryURL:(NSURL *)backupDirectoryURL NS_DESIGNATED_INITIALIZER;

- (NSDictionary<NSString *, id> *)allSettings;
- (BOOL)boolForKey:(NSString *)key defaultValue:(BOOL)defaultValue;
- (NSInteger)integerForKey:(NSString *)key defaultValue:(NSInteger)defaultValue;
- (double)doubleForKey:(NSString *)key defaultValue:(double)defaultValue;
- (void)setBool:(BOOL)value forKey:(NSString *)key;
- (void)setInteger:(NSInteger)value forKey:(NSString *)key;
- (void)setDouble:(double)value forKey:(NSString *)key;

/// Returns an immutable, detached property-list snapshot.
- (nullable NSArray<NSDictionary<NSString *, id> *> *)commandApplicationsForCollection:(JTCommandCollection)collection
                                                                                   error:(NSError **)error;
- (nullable NSArray<NSDictionary<NSString *, id> *> *)commandsForKey:(NSString *)key
                                                               error:(NSError **)error;
- (nullable NSDictionary<NSString *, id> *)gestureCommandAtIndex:(NSUInteger)gestureIndex
                                               applicationIndex:(NSUInteger)applicationIndex
                                                      collection:(JTCommandCollection)collection
                                                           error:(NSError **)error;

- (BOOL)addCommandApplication:(NSDictionary<NSString *, id> *)application
                  toCollection:(JTCommandCollection)collection
                         error:(NSError **)error;
- (BOOL)updateCommandApplicationAtIndex:(NSUInteger)applicationIndex
                         withApplication:(NSDictionary<NSString *, id> *)application
                              collection:(JTCommandCollection)collection
                                   error:(NSError **)error;
- (BOOL)removeCommandApplicationAtIndex:(NSUInteger)applicationIndex
                              collection:(JTCommandCollection)collection
                                   error:(NSError **)error;
- (BOOL)addGestureCommand:(NSDictionary<NSString *, id> *)command
       toApplicationAtIndex:(NSUInteger)applicationIndex
                  collection:(JTCommandCollection)collection
                       error:(NSError **)error;
- (BOOL)updateGestureCommandAtIndex:(NSUInteger)gestureIndex
                   applicationIndex:(NSUInteger)applicationIndex
                        withCommand:(NSDictionary<NSString *, id> *)command
                         collection:(JTCommandCollection)collection
                              error:(NSError **)error;
- (BOOL)removeGestureCommandAtIndex:(NSUInteger)gestureIndex
                    applicationIndex:(NSUInteger)applicationIndex
                         collection:(JTCommandCollection)collection
                              error:(NSError **)error;

/// Name-based conveniences used by the editor. `replacingGesture` may be nil
/// to append; if the named application or gesture is absent, upsert creates it.
/// Applications are uniquely matched by display name. Updating an existing
/// application also replaces its saved path with the supplied path.
- (BOOL)upsertCommand:(NSDictionary<NSString *, id> *)command
           application:(NSString *)application
                  path:(NSString *)path
      replacingGesture:(nullable NSString *)replacingGesture
                forKey:(NSString *)key
                 error:(NSError **)error;
- (BOOL)removeCommandForApplication:(NSString *)application
                             gesture:(NSString *)gesture
                              forKey:(NSString *)key
                               error:(NSError **)error;
- (BOOL)setCommandEnabled:(BOOL)enabled
            forApplication:(NSString *)application
                    gesture:(NSString *)gesture
                     forKey:(NSString *)key
                      error:(NSError **)error;

/// Validates all present Trackpad, Magic Mouse, and Recognition command trees.
- (BOOL)validateCommandStructureInSettings:(NSDictionary<NSString *, id> *)candidate
                                     error:(NSError **)error;
- (void)reload;

@end

FOUNDATION_EXPORT NSNotificationName const JTSettingsStoreDidChangeNotification;

NS_ASSUME_NONNULL_END
