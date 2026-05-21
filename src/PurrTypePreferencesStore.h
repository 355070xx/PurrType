#import <Foundation/Foundation.h>
#import "PurrTypeEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface PurrTypePreferencesStore : NSObject

+ (instancetype)sharedStore;

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

- (void)synchronize;
- (BOOL)isSupportedEngineMode:(nullable NSString *)mode;
- (BOOL)isEngineModeEnabled:(nullable NSString *)mode;

- (MKInputMode)engineMode;
- (void)setEngineMode:(MKInputMode)mode;
- (BOOL)learningEnabled;
- (void)setLearningEnabled:(BOOL)enabled;
- (BOOL)privacyLockEnabled;
- (void)setPrivacyLockEnabled:(BOOL)enabled;
- (BOOL)rawEnglishCandidateEnabled;
- (void)setRawEnglishCandidateEnabled:(BOOL)enabled;
- (BOOL)spellingSuggestionsEnabled;
- (void)setSpellingSuggestionsEnabled:(BOOL)enabled;
- (BOOL)spacePagingEnabled;
- (void)setSpacePagingEnabled:(BOOL)enabled;
- (NSUInteger)candidatePageSize;
- (void)setCandidatePageSize:(NSUInteger)pageSize;
- (NSArray<MKInputMode> *)enabledInputModes;
- (void)setEnabledInputModes:(NSArray<NSString *> *)enabledInputModes;
- (NSString *)switchInputModeShortcut;
- (void)setSwitchInputModeShortcut:(NSString *)shortcutSpec;
- (NSString *)privacyLockShortcut;
- (void)setPrivacyLockShortcut:(NSString *)shortcutSpec;
- (NSDictionary<NSString *, NSString *> *)modeShortcutsByMode;
- (BOOL)setModeShortcut:(NSString *)shortcutSpec forMode:(MKInputMode)mode;

- (void)requestLearningReset;
- (BOOL)hasPendingLearningReset;
- (void)clearPendingLearningReset;

- (void)postPreferencesChangedNotification;
- (void)postPreferencesChangedNotificationWithUserInfo:(nullable NSDictionary *)userInfo;

@end

NS_ASSUME_NONNULL_END
