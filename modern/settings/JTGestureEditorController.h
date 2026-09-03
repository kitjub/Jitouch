#import <Cocoa/Cocoa.h>

@class JTSettingsStore;

NS_ASSUME_NONNULL_BEGIN

/// Edits one of the legacy command arrays without normalizing or discarding
/// commands unknown to this version of the UI.
@interface JTGestureEditorController : NSViewController

- (instancetype)initWithStore:(JTSettingsStore *)store
                   commandsKey:(NSString *)commandsKey
                   deviceTitle:(NSString *)deviceTitle
                gestureCatalog:(NSArray<NSString *> *)gestureCatalog NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSNibName)nibNameOrNil
                         bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
