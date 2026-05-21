#import <Cocoa/Cocoa.h>

@class PurrTypeEngine;

NS_ASSUME_NONNULL_BEGIN

@protocol PurrTypePreferencesWindowControllerDelegate <NSObject>

- (NSString *)preferencesCurrentMode;
- (void)preferencesSwitchToMode:(NSString *)mode;
- (BOOL)preferencesLearningEnabled;
- (void)preferencesSetLearningEnabled:(BOOL)enabled;
- (BOOL)preferencesPrivacyLockEnabled;
- (void)preferencesSetPrivacyLockEnabled:(BOOL)enabled;
- (BOOL)preferencesRawEnglishCandidateEnabled;
- (void)preferencesSetRawEnglishCandidateEnabled:(BOOL)enabled;
- (BOOL)preferencesSpellingSuggestionsEnabled;
- (void)preferencesSetSpellingSuggestionsEnabled:(BOOL)enabled;
- (BOOL)preferencesSpacePagingEnabled;
- (void)preferencesSetSpacePagingEnabled:(BOOL)enabled;
- (NSUInteger)preferencesCandidatePageSize;
- (void)preferencesSetCandidatePageSize:(NSUInteger)pageSize;
- (NSArray<NSString *> *)preferencesEnabledInputModes;
- (void)preferencesSetEnabledInputModes:(NSArray<NSString *> *)enabledInputModes;
- (NSString *)preferencesSwitchInputModeShortcut;
- (void)preferencesSetSwitchInputModeShortcut:(NSString *)shortcutSpec;
- (NSString *)preferencesPrivacyLockShortcut;
- (void)preferencesSetPrivacyLockShortcut:(NSString *)shortcutSpec;
- (NSDictionary<NSString *, NSString *> *)preferencesModeShortcutsByMode;
- (void)preferencesSetModeShortcut:(NSString *)shortcutSpec forMode:(NSString *)mode;
- (void)preferencesResetLearning;

@end

@interface PurrTypePreferencesWindowController : NSWindowController

+ (instancetype)sharedController;
- (void)showWithEngine:(nullable PurrTypeEngine *)engine
              delegate:(id<PurrTypePreferencesWindowControllerDelegate>)delegate;
- (void)reloadState;

@end

NS_ASSUME_NONNULL_END
