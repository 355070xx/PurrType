#import <Foundation/Foundation.h>
#import "PurrTypeEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface PurrTypeInputBehavior : NSObject

+ (NSUInteger)candidatePageSize;
+ (NSArray<MKInputMode> *)orderedInputModes;
+ (NSArray<MKInputMode> *)defaultEnabledInputModes;
+ (NSArray<MKInputMode> *)normalizedEnabledInputModes:(nullable NSArray<NSString *> *)inputModes;
+ (nullable MKInputMode)firstEnabledInputModeInModes:(nullable NSArray<NSString *> *)inputModes;
+ (BOOL)inputMode:(MKInputMode)mode isEnabledInModes:(nullable NSArray<NSString *> *)inputModes;
+ (nullable MKInputMode)modeForShortcutKeyCode:(NSInteger)keyCode modifiers:(NSUInteger)flags;
+ (nullable MKInputMode)modeForShortcutKeyCode:(NSInteger)keyCode
                                     modifiers:(NSUInteger)flags
                               shortcutsByMode:(NSDictionary<NSString *, NSString *> *)shortcutsByMode;
+ (nullable MKInputMode)modeForShortcutKeyCode:(NSInteger)keyCode
                                     modifiers:(NSUInteger)flags
                               shortcutsByMode:(NSDictionary<NSString *, NSString *> *)shortcutsByMode
                                  enabledModes:(nullable NSArray<NSString *> *)enabledModes;
+ (BOOL)isPreferencesShortcutKeyCode:(NSInteger)keyCode modifiers:(NSUInteger)flags;
+ (NSString *)defaultSwitchInputModeShortcutSpec;
+ (NSString *)defaultModeShortcutSpecForMode:(MKInputMode)mode;
+ (NSString *)defaultPrivacyLockShortcutSpec;
+ (NSArray<NSString *> *)availableModeShortcutSpecs;
+ (NSArray<NSString *> *)availablePrivacyLockShortcutSpecs;
+ (nullable NSString *)shortcutSpecForKeyCode:(NSInteger)keyCode modifiers:(NSUInteger)flags;
+ (NSString *)normalizedSwitchInputModeShortcutSpec:(nullable NSString *)shortcutSpec;
+ (NSString *)normalizedModeShortcutSpec:(nullable NSString *)shortcutSpec forMode:(MKInputMode)mode;
+ (NSString *)normalizedPrivacyLockShortcutSpec:(nullable NSString *)shortcutSpec;
+ (NSString *)displayNameForShortcutSpec:(nullable NSString *)shortcutSpec;
+ (NSString *)keyEquivalentForShortcutSpec:(nullable NSString *)shortcutSpec;
+ (NSUInteger)keyEquivalentModifierMaskForShortcutSpec:(nullable NSString *)shortcutSpec;
+ (BOOL)shortcutSpec:(nullable NSString *)shortcutSpec matchesKeyCode:(NSInteger)keyCode modifiers:(NSUInteger)flags;
+ (BOOL)shortcutSpec:(nullable NSString *)firstShortcutSpec conflictsWithShortcutSpec:(nullable NSString *)secondShortcutSpec;
+ (BOOL)isDoubleBacktickShortcutSpec:(nullable NSString *)shortcutSpec;
+ (BOOL)isBacktickKeyCode:(NSInteger)keyCode inputString:(nullable NSString *)string modifiers:(NSUInteger)flags;
+ (BOOL)privacyLockShouldPauseLearningContextForMode:(MKInputMode)mode enabled:(BOOL)enabled;
+ (NSInteger)candidatePageOffsetForKeyCode:(NSInteger)keyCode
                                 modifiers:(NSUInteger)flags
                            candidateCount:(NSUInteger)candidateCount
                        spacePagingEnabled:(BOOL)spacePagingEnabled;
+ (NSInteger)candidatePageOffsetForKeyCode:(NSInteger)keyCode
                                 modifiers:(NSUInteger)flags
                            candidateCount:(NSUInteger)candidateCount
                        spacePagingEnabled:(BOOL)spacePagingEnabled
                         candidatePageSize:(NSUInteger)candidatePageSize;
+ (NSInteger)candidatePageOffsetForSelector:(SEL)selector
                             candidateCount:(NSUInteger)candidateCount
                          candidatePageSize:(NSUInteger)candidatePageSize;
+ (NSInteger)candidateSelectionOffsetForKeyCode:(NSInteger)keyCode
                                      modifiers:(NSUInteger)flags
                                 candidateCount:(NSUInteger)candidateCount;
+ (NSInteger)candidateSelectionOffsetForSelector:(SEL)selector
                                  candidateCount:(NSUInteger)candidateCount;
+ (NSUInteger)candidateSelectionIndexFromIndex:(NSUInteger)selectedIndex
                                        offset:(NSInteger)offset
                                candidateCount:(NSUInteger)candidateCount;
+ (NSArray<MKCandidate *> *)candidatePageFromPool:(NSArray<MKCandidate *> *)candidatePool
                                       pageIndex:(NSUInteger *)pageIndex;
+ (NSArray<MKCandidate *> *)candidatePageFromPool:(NSArray<MKCandidate *> *)candidatePool
                                       pageIndex:(NSUInteger *)pageIndex
                                        pageSize:(NSUInteger)pageSize;
+ (NSUInteger)spellingSuggestionLimitForCandidatePageSize:(NSUInteger)pageSize;
+ (NSArray<MKCandidate *> *)candidatePoolByMergingPrimaryCandidates:(NSArray<MKCandidate *> *)primaryCandidates
                                                spellingCandidates:(NSArray<MKCandidate *> *)spellingCandidates
                                                          pageSize:(NSUInteger)pageSize;
+ (NSString *)displayTextForCandidate:(MKCandidate *)candidate index:(NSUInteger)index;
+ (NSArray<NSString *> *)displayTextsForCandidates:(NSArray<MKCandidate *> *)candidates
                                            buffer:(NSString *)buffer
                         rawEnglishModeActive:(BOOL)rawEnglishModeActive
                         associationModeActive:(BOOL)associationModeActive
                    rawEnglishCandidateEnabled:(BOOL)rawEnglishCandidateEnabled;
+ (BOOL)shouldShowRawEnglishCandidateForBuffer:(NSString *)buffer
                       rawEnglishModeActive:(BOOL)rawEnglishModeActive
                       associationModeActive:(BOOL)associationModeActive
                  rawEnglishCandidateEnabled:(BOOL)rawEnglishCandidateEnabled
                              candidateCount:(NSUInteger)candidateCount;
+ (NSString *)rawEnglishCandidateDisplayTextForBuffer:(NSString *)buffer;
+ (NSArray<NSString *> *)punctuationCandidateDisplayTextsForString:(NSString *)string;
+ (nullable NSString *)punctuationTextForDisplayText:(NSString *)displayText;
+ (BOOL)shouldAutoCommitDefaultPunctuationForInputString:(nullable NSString *)string
                                                keyCode:(NSInteger)keyCode
                                         candidateCount:(NSUInteger)candidateCount;
+ (BOOL)isShiftOnlyLetterInputWithModifiers:(NSUInteger)flags;
+ (BOOL)isAsciiCodeString:(NSString *)string;

@end

NS_ASSUME_NONNULL_END
