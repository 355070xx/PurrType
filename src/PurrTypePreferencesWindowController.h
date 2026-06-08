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
- (NSString *)preferencesRawEnglishCandidatePosition;
- (void)preferencesSetRawEnglishCandidatePosition:(NSString *)position;
- (BOOL)preferencesSpellingSuggestionsEnabled;
- (void)preferencesSetSpellingSuggestionsEnabled:(BOOL)enabled;
- (BOOL)preferencesSpacePagingEnabled;
- (void)preferencesSetSpacePagingEnabled:(BOOL)enabled;
- (BOOL)preferencesDecimalPointShortcutEnabled;
- (void)preferencesSetDecimalPointShortcutEnabled:(BOOL)enabled;
- (BOOL)preferencesChineseContextPunctuationEnabled;
- (void)preferencesSetChineseContextPunctuationEnabled:(BOOL)enabled;
- (NSUInteger)preferencesCandidatePageSize;
- (void)preferencesSetCandidatePageSize:(NSUInteger)pageSize;
- (NSString *)preferencesCandidatePanelOrientation;
- (void)preferencesSetCandidatePanelOrientation:(NSString *)orientation;
- (CGFloat)preferencesCandidatePanelFontSize;
- (void)preferencesSetCandidatePanelFontSize:(CGFloat)fontSize;
- (NSString *)preferencesCandidatePanelHighlightColor;
- (void)preferencesSetCandidatePanelHighlightColor:(NSString *)highlightColor;
- (BOOL)preferencesAssociationCandidatesEnabled;
- (void)preferencesSetAssociationCandidatesEnabled:(BOOL)enabled;
- (BOOL)preferencesAssociationContinuationEnabled;
- (void)preferencesSetAssociationContinuationEnabled:(BOOL)enabled;
- (NSUInteger)preferencesCandidatePageSizeOverrideForMode:(NSString *)mode;
- (void)preferencesSetCandidatePageSizeOverride:(NSUInteger)pageSize forMode:(NSString *)mode;
- (NSString *)preferencesSpaceKeyOverrideForMode:(NSString *)mode;
- (void)preferencesSetSpaceKeyOverride:(NSString *)overrideValue forMode:(NSString *)mode;
- (BOOL)preferencesClearReadingOnCompositionFailureEnabledForMode:(NSString *)mode;
- (void)preferencesSetClearReadingOnCompositionFailureEnabled:(BOOL)enabled forMode:(NSString *)mode;
- (void)preferencesResetOverridesForMode:(NSString *)mode;
- (NSArray<NSString *> *)preferencesEnabledInputModes;
- (void)preferencesSetEnabledInputModes:(NSArray<NSString *> *)enabledInputModes;
- (NSString *)preferencesSwitchInputModeShortcut;
- (void)preferencesSetSwitchInputModeShortcut:(NSString *)shortcutSpec;
- (NSString *)preferencesPrivacyLockShortcut;
- (void)preferencesSetPrivacyLockShortcut:(NSString *)shortcutSpec;
- (NSString *)preferencesVoiceRecognitionLocaleIdentifier;
- (void)preferencesSetVoiceRecognitionLocaleIdentifier:(NSString *)localeIdentifier;
- (BOOL)preferencesVoiceFloatingButtonVisible;
- (void)preferencesSetVoiceFloatingButtonVisible:(BOOL)visible;
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
