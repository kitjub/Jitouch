#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// A small, dependency-free shortcut recorder. Values use CGEvent flag bits,
/// matching the legacy Jitouch `ModifierFlags` and `KeyCode` schema.
@interface JTShortcutRecorderField : NSTextField

@property(nonatomic) NSUInteger modifierFlags;
@property(nonatomic) CGKeyCode keyCode;
@property(nonatomic, readonly) BOOL hasRecordedShortcut;
/// Called only after a person records a new key combination. Loading an
/// existing value with setModifierFlags:keyCode: does not invoke it.
@property(nonatomic, copy, nullable) void (^recordingHandler)(
    JTShortcutRecorderField *field);

- (void)setModifierFlags:(NSUInteger)modifierFlags keyCode:(CGKeyCode)keyCode;
- (void)clearShortcut;

@end

NS_ASSUME_NONNULL_END
