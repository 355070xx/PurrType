#import "PurrTypePreferencesStore.h"
#import "PurrTypeInputBehavior.h"
#import "PurrTypePreferencesConstants.h"

@interface PurrTypePreferencesStore ()

@property(nonatomic, strong) NSUserDefaults *defaults;

- (NSString *)userDefaultShortcutKeyForMode:(MKInputMode)mode;
- (MKInputMode)fallbackEngineModeForEnabledModes:(NSArray<NSString *> *)enabledModes;
- (NSDictionary<NSString *, id> *)modeOverridesForKey:(NSString *)key;
- (void)setModeOverrideValue:(id)value forMode:(MKInputMode)mode key:(NSString *)key;
- (NSString *)normalizedSpaceKeyOverride:(NSString *)overrideValue;
- (NSString *)normalizedRawEnglishCandidatePosition:(NSString *)position;
- (NSString *)normalizedCandidatePanelOrientation:(NSString *)orientation;
- (CGFloat)normalizedCandidatePanelFontSize:(CGFloat)fontSize;
- (NSString *)normalizedCandidatePanelHighlightColor:(NSString *)highlightColor;
- (NSString *)normalizedVoiceRecognitionLocaleIdentifier:(nullable NSString *)localeIdentifier;

@end

@implementation PurrTypePreferencesStore

+ (instancetype)sharedStore {
    static PurrTypePreferencesStore *store = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSUserDefaults *defaults = nil;
        if ([[NSBundle mainBundle].bundleIdentifier isEqualToString:MKUserDefaultsSuiteName]) {
            defaults = [NSUserDefaults standardUserDefaults];
        } else {
            defaults = [[NSUserDefaults alloc] initWithSuiteName:MKUserDefaultsSuiteName];
        }
        store = [[PurrTypePreferencesStore alloc] initWithDefaults:defaults ?: [NSUserDefaults standardUserDefaults]];
    });
    return store;
}

- (instancetype)initWithDefaults:(NSUserDefaults *)defaults {
    self = [super init];
    if (self) {
        _defaults = defaults ?: [NSUserDefaults standardUserDefaults];
    }
    return self;
}

- (void)synchronize {
    [self.defaults synchronize];
}

- (BOOL)isSupportedEngineMode:(NSString *)mode {
    return [mode isEqualToString:MKInputModeCangjie] ||
           [mode isEqualToString:MKInputModeSucheng] ||
           [mode isEqualToString:MKInputModeSmartSucheng] ||
           [mode isEqualToString:MKInputModePinyin];
}

- (BOOL)isEngineModeEnabled:(NSString *)mode {
    return [self isSupportedEngineMode:mode] &&
           [PurrTypeInputBehavior inputMode:mode isEnabledInModes:[self enabledInputModes]];
}

- (MKInputMode)engineMode {
    NSString *savedMode = [self.defaults stringForKey:MKUserDefaultEngineModeKey];
    NSArray<NSString *> *enabledModes = [self enabledInputModes];
    if ([self isSupportedEngineMode:savedMode] &&
        [PurrTypeInputBehavior inputMode:savedMode isEnabledInModes:enabledModes]) {
        return savedMode;
    }

    MKInputMode fallbackMode = [self fallbackEngineModeForEnabledModes:enabledModes];
    [self.defaults setObject:fallbackMode forKey:MKUserDefaultEngineModeKey];
    [self.defaults synchronize];
    return fallbackMode;
}

- (void)setEngineMode:(MKInputMode)mode {
    if (![self isEngineModeEnabled:mode]) {
        return;
    }
    [self.defaults setObject:mode forKey:MKUserDefaultEngineModeKey];
    [self.defaults synchronize];
}

- (BOOL)learningEnabled {
    id savedValue = [self.defaults objectForKey:MKUserDefaultLearningEnabledKey];
    if ([savedValue respondsToSelector:@selector(boolValue)]) {
        return [savedValue boolValue];
    }
    return NO;
}

- (void)setLearningEnabled:(BOOL)enabled {
    [self.defaults setBool:enabled forKey:MKUserDefaultLearningEnabledKey];
    [self.defaults synchronize];
}

- (BOOL)privacyLockEnabled {
    id savedValue = [self.defaults objectForKey:MKUserDefaultPrivacyLockEnabledKey];
    if ([savedValue respondsToSelector:@selector(boolValue)]) {
        return [savedValue boolValue];
    }
    return NO;
}

- (void)setPrivacyLockEnabled:(BOOL)enabled {
    [self.defaults setBool:enabled forKey:MKUserDefaultPrivacyLockEnabledKey];
    [self.defaults synchronize];
}

- (BOOL)rawEnglishCandidateEnabled {
    id savedValue = [self.defaults objectForKey:MKUserDefaultRawEnglishCandidateEnabledKey];
    if ([savedValue respondsToSelector:@selector(boolValue)]) {
        return [savedValue boolValue];
    }
    return YES;
}

- (void)setRawEnglishCandidateEnabled:(BOOL)enabled {
    [self.defaults setBool:enabled forKey:MKUserDefaultRawEnglishCandidateEnabledKey];
    [self.defaults synchronize];
}

- (NSString *)rawEnglishCandidatePosition {
    return [self normalizedRawEnglishCandidatePosition:[self.defaults stringForKey:MKUserDefaultRawEnglishCandidatePositionKey]];
}

- (void)setRawEnglishCandidatePosition:(NSString *)position {
    [self.defaults setObject:[self normalizedRawEnglishCandidatePosition:position]
                      forKey:MKUserDefaultRawEnglishCandidatePositionKey];
    [self.defaults synchronize];
}

- (BOOL)spellingSuggestionsEnabled {
    id savedValue = [self.defaults objectForKey:MKUserDefaultSpellingSuggestionsEnabledKey];
    if ([savedValue respondsToSelector:@selector(boolValue)]) {
        return [savedValue boolValue];
    }
    return YES;
}

- (void)setSpellingSuggestionsEnabled:(BOOL)enabled {
    [self.defaults setBool:enabled forKey:MKUserDefaultSpellingSuggestionsEnabledKey];
    [self.defaults synchronize];
}

- (BOOL)spacePagingEnabled {
    id savedValue = [self.defaults objectForKey:MKUserDefaultSpacePagingEnabledKey];
    if ([savedValue respondsToSelector:@selector(boolValue)]) {
        return [savedValue boolValue];
    }
    return YES;
}

- (void)setSpacePagingEnabled:(BOOL)enabled {
    [self.defaults setBool:enabled forKey:MKUserDefaultSpacePagingEnabledKey];
    [self.defaults synchronize];
}

- (BOOL)decimalPointShortcutEnabled {
    id savedValue = [self.defaults objectForKey:MKUserDefaultDecimalPointShortcutEnabledKey];
    if ([savedValue respondsToSelector:@selector(boolValue)]) {
        return [savedValue boolValue];
    }
    return YES;
}

- (void)setDecimalPointShortcutEnabled:(BOOL)enabled {
    [self.defaults setBool:enabled forKey:MKUserDefaultDecimalPointShortcutEnabledKey];
    [self.defaults synchronize];
}

- (BOOL)chineseContextPunctuationEnabled {
    id savedValue = [self.defaults objectForKey:MKUserDefaultChineseContextPunctuationEnabledKey];
    if ([savedValue respondsToSelector:@selector(boolValue)]) {
        return [savedValue boolValue];
    }
    return YES;
}

- (void)setChineseContextPunctuationEnabled:(BOOL)enabled {
    [self.defaults setBool:enabled forKey:MKUserDefaultChineseContextPunctuationEnabledKey];
    [self.defaults synchronize];
}

- (NSUInteger)candidatePageSize {
    id savedValue = [self.defaults objectForKey:MKUserDefaultCandidatePageSizeKey];
    if ([savedValue respondsToSelector:@selector(unsignedIntegerValue)]) {
        NSUInteger pageSize = [savedValue unsignedIntegerValue];
        if (pageSize == 5 || pageSize == 9) {
            return pageSize;
        }
    }
    return [PurrTypeInputBehavior candidatePageSize];
}

- (void)setCandidatePageSize:(NSUInteger)pageSize {
    if (pageSize != 5 && pageSize != 9) {
        pageSize = [PurrTypeInputBehavior candidatePageSize];
    }
    [self.defaults setInteger:(NSInteger)pageSize forKey:MKUserDefaultCandidatePageSizeKey];
    [self.defaults synchronize];
}

- (NSString *)candidatePanelOrientation {
    return [self normalizedCandidatePanelOrientation:[self.defaults stringForKey:MKUserDefaultCandidatePanelOrientationKey]];
}

- (void)setCandidatePanelOrientation:(NSString *)orientation {
    [self.defaults setObject:[self normalizedCandidatePanelOrientation:orientation]
                      forKey:MKUserDefaultCandidatePanelOrientationKey];
    [self.defaults synchronize];
}

- (CGFloat)candidatePanelFontSize {
    id savedValue = [self.defaults objectForKey:MKUserDefaultCandidatePanelFontSizeKey];
    if ([savedValue respondsToSelector:@selector(doubleValue)]) {
        return [self normalizedCandidatePanelFontSize:[savedValue doubleValue]];
    }
    return 17.0;
}

- (void)setCandidatePanelFontSize:(CGFloat)fontSize {
    [self.defaults setDouble:[self normalizedCandidatePanelFontSize:fontSize]
                      forKey:MKUserDefaultCandidatePanelFontSizeKey];
    [self.defaults synchronize];
}

- (NSString *)candidatePanelHighlightColor {
    return [self normalizedCandidatePanelHighlightColor:[self.defaults stringForKey:MKUserDefaultCandidatePanelHighlightColorKey]];
}

- (void)setCandidatePanelHighlightColor:(NSString *)highlightColor {
    [self.defaults setObject:[self normalizedCandidatePanelHighlightColor:highlightColor]
                      forKey:MKUserDefaultCandidatePanelHighlightColorKey];
    [self.defaults synchronize];
}

- (BOOL)associationCandidatesEnabled {
    id savedValue = [self.defaults objectForKey:MKUserDefaultAssociationCandidatesEnabledKey];
    if ([savedValue respondsToSelector:@selector(boolValue)]) {
        return [savedValue boolValue];
    }
    return YES;
}

- (void)setAssociationCandidatesEnabled:(BOOL)enabled {
    [self.defaults setBool:enabled forKey:MKUserDefaultAssociationCandidatesEnabledKey];
    [self.defaults synchronize];
}

- (BOOL)associationContinuationEnabled {
    id savedValue = [self.defaults objectForKey:MKUserDefaultAssociationContinuationEnabledKey];
    if ([savedValue respondsToSelector:@selector(boolValue)]) {
        return [savedValue boolValue];
    }
    return YES;
}

- (void)setAssociationContinuationEnabled:(BOOL)enabled {
    [self.defaults setBool:enabled forKey:MKUserDefaultAssociationContinuationEnabledKey];
    [self.defaults synchronize];
}

- (NSUInteger)candidatePageSizeOverrideForMode:(MKInputMode)mode {
    if (![self isSupportedEngineMode:mode]) {
        return 0;
    }
    id value = [self modeOverridesForKey:MKUserDefaultModeCandidatePageSizeOverridesKey][mode];
    if ([value respondsToSelector:@selector(unsignedIntegerValue)]) {
        NSUInteger pageSize = [value unsignedIntegerValue];
        if (pageSize == 5 || pageSize == 9) {
            return pageSize;
        }
    }
    return 0;
}

- (void)setCandidatePageSizeOverride:(NSUInteger)pageSize forMode:(MKInputMode)mode {
    if (![self isSupportedEngineMode:mode]) {
        return;
    }
    if (pageSize != 5 && pageSize != 9) {
        [self setModeOverrideValue:nil forMode:mode key:MKUserDefaultModeCandidatePageSizeOverridesKey];
        return;
    }
    [self setModeOverrideValue:@(pageSize) forMode:mode key:MKUserDefaultModeCandidatePageSizeOverridesKey];
}

- (NSUInteger)effectiveCandidatePageSizeForMode:(MKInputMode)mode {
    NSUInteger overridePageSize = [self candidatePageSizeOverrideForMode:mode];
    return overridePageSize > 0 ? overridePageSize : [self candidatePageSize];
}

- (NSString *)spaceKeyOverrideForMode:(MKInputMode)mode {
    if (![self isSupportedEngineMode:mode]) {
        return MKModeOverrideFollowGlobal;
    }
    id value = [self modeOverridesForKey:MKUserDefaultModeSpaceKeyOverridesKey][mode];
    return [self normalizedSpaceKeyOverride:[value isKindOfClass:[NSString class]] ? value : nil];
}

- (void)setSpaceKeyOverride:(NSString *)overrideValue forMode:(MKInputMode)mode {
    if (![self isSupportedEngineMode:mode]) {
        return;
    }
    NSString *normalized = [self normalizedSpaceKeyOverride:overrideValue];
    [self setModeOverrideValue:[normalized isEqualToString:MKModeOverrideFollowGlobal] ? nil : normalized
                       forMode:mode
                           key:MKUserDefaultModeSpaceKeyOverridesKey];
}

- (BOOL)effectiveSpacePagingEnabledForMode:(MKInputMode)mode {
    NSString *overrideValue = [self spaceKeyOverrideForMode:mode];
    if ([overrideValue isEqualToString:MKModeSpaceKeyCommitFirst]) {
        return NO;
    }
    if ([overrideValue isEqualToString:MKModeSpaceKeyPageCandidates]) {
        return YES;
    }
    return [self spacePagingEnabled];
}

- (BOOL)clearReadingOnCompositionFailureEnabledForMode:(MKInputMode)mode {
    if (![self isSupportedEngineMode:mode]) {
        return NO;
    }
    id value = [self modeOverridesForKey:MKUserDefaultModeClearReadingOnFailureOverridesKey][mode];
    return [value respondsToSelector:@selector(boolValue)] && [value boolValue];
}

- (void)setClearReadingOnCompositionFailureEnabled:(BOOL)enabled forMode:(MKInputMode)mode {
    if (![self isSupportedEngineMode:mode]) {
        return;
    }
    [self setModeOverrideValue:enabled ? @YES : nil
                       forMode:mode
                           key:MKUserDefaultModeClearReadingOnFailureOverridesKey];
}

- (void)resetOverridesForMode:(MKInputMode)mode {
    if (![self isSupportedEngineMode:mode]) {
        return;
    }
    [self setModeOverrideValue:nil forMode:mode key:MKUserDefaultModeCandidatePageSizeOverridesKey];
    [self setModeOverrideValue:nil forMode:mode key:MKUserDefaultModeSpaceKeyOverridesKey];
    [self setModeOverrideValue:nil forMode:mode key:MKUserDefaultModeClearReadingOnFailureOverridesKey];
}

- (NSArray<MKInputMode> *)enabledInputModes {
    id savedValue = [self.defaults objectForKey:MKUserDefaultEnabledInputModesKey];
    return [PurrTypeInputBehavior normalizedEnabledInputModes:[savedValue isKindOfClass:[NSArray class]] ? savedValue : nil];
}

- (void)setEnabledInputModes:(NSArray<NSString *> *)enabledInputModes {
    NSArray<NSString *> *normalizedModes = [PurrTypeInputBehavior normalizedEnabledInputModes:enabledInputModes];
    [self.defaults setObject:normalizedModes forKey:MKUserDefaultEnabledInputModesKey];

    NSString *currentMode = [self.defaults stringForKey:MKUserDefaultEngineModeKey];
    if (![PurrTypeInputBehavior inputMode:currentMode isEnabledInModes:normalizedModes]) {
        [self.defaults setObject:[self fallbackEngineModeForEnabledModes:normalizedModes]
                          forKey:MKUserDefaultEngineModeKey];
    }

    [self.defaults synchronize];
}

- (NSString *)switchInputModeShortcut {
    NSString *savedShortcut = [self.defaults stringForKey:MKUserDefaultSwitchInputModeShortcutKey];
    return [PurrTypeInputBehavior normalizedSwitchInputModeShortcutSpec:savedShortcut];
}

- (void)setSwitchInputModeShortcut:(NSString *)shortcutSpec {
    NSString *normalizedShortcut = [PurrTypeInputBehavior normalizedSwitchInputModeShortcutSpec:shortcutSpec];
    [self.defaults setObject:normalizedShortcut forKey:MKUserDefaultSwitchInputModeShortcutKey];
    [self.defaults synchronize];
}

- (NSString *)privacyLockShortcut {
    NSString *savedShortcut = [self.defaults stringForKey:MKUserDefaultPrivacyLockShortcutKey];
    return [PurrTypeInputBehavior normalizedPrivacyLockShortcutSpec:savedShortcut];
}

- (void)setPrivacyLockShortcut:(NSString *)shortcutSpec {
    NSString *normalizedShortcut = [PurrTypeInputBehavior normalizedPrivacyLockShortcutSpec:shortcutSpec];
    [self.defaults setObject:normalizedShortcut forKey:MKUserDefaultPrivacyLockShortcutKey];
    [self.defaults synchronize];
}

- (NSString *)voiceRecognitionLocaleIdentifier {
    return [self normalizedVoiceRecognitionLocaleIdentifier:[self.defaults stringForKey:MKUserDefaultVoiceRecognitionLocaleKey]];
}

- (void)setVoiceRecognitionLocaleIdentifier:(NSString *)localeIdentifier {
    [self.defaults setObject:[self normalizedVoiceRecognitionLocaleIdentifier:localeIdentifier]
                      forKey:MKUserDefaultVoiceRecognitionLocaleKey];
    [self.defaults synchronize];
}

- (BOOL)voiceFloatingButtonVisible {
    id savedValue = [self.defaults objectForKey:MKUserDefaultVoiceFloatingButtonVisibleKey];
    if ([savedValue respondsToSelector:@selector(boolValue)]) {
        return [savedValue boolValue];
    }
    return YES;
}

- (void)setVoiceFloatingButtonVisible:(BOOL)visible {
    [self.defaults setBool:visible forKey:MKUserDefaultVoiceFloatingButtonVisibleKey];
    [self.defaults synchronize];
}

- (NSDictionary<NSString *, NSString *> *)modeShortcutsByMode {
    NSArray<NSString *> *modes = @[MKInputModeSucheng, MKInputModeSmartSucheng, MKInputModeCangjie, MKInputModePinyin];
    NSMutableDictionary<NSString *, NSString *> *shortcuts = [NSMutableDictionary dictionaryWithCapacity:modes.count];
    for (NSString *mode in modes) {
        NSString *savedShortcut = [self.defaults stringForKey:[self userDefaultShortcutKeyForMode:mode]];
        shortcuts[mode] = [PurrTypeInputBehavior normalizedModeShortcutSpec:savedShortcut forMode:mode];
    }
    return shortcuts;
}

- (BOOL)setModeShortcut:(NSString *)shortcutSpec forMode:(MKInputMode)mode {
    if (![self isSupportedEngineMode:mode]) {
        return NO;
    }

    NSString *normalizedShortcut = [PurrTypeInputBehavior normalizedModeShortcutSpec:shortcutSpec forMode:mode];
    NSArray<NSString *> *modes = @[MKInputModeSucheng, MKInputModeSmartSucheng, MKInputModeCangjie, MKInputModePinyin];
    if (![normalizedShortcut isEqualToString:@"none"]) {
        for (NSString *otherMode in modes) {
            if ([otherMode isEqualToString:mode]) {
                continue;
            }
            NSString *otherKey = [self userDefaultShortcutKeyForMode:otherMode];
            NSString *otherShortcut = [PurrTypeInputBehavior normalizedModeShortcutSpec:[self.defaults stringForKey:otherKey]
                                                                                  forMode:otherMode];
            if ([PurrTypeInputBehavior shortcutSpec:otherShortcut conflictsWithShortcutSpec:normalizedShortcut]) {
                return NO;
            }
        }
    }

    [self.defaults setObject:normalizedShortcut forKey:[self userDefaultShortcutKeyForMode:mode]];
    [self.defaults synchronize];
    return YES;
}

- (void)requestLearningReset {
    NSString *requestIdentifier = [NSUUID UUID].UUIDString;
    [self.defaults setObject:requestIdentifier forKey:MKUserDefaultLearningResetRequestKey];
    [self.defaults synchronize];
    [self postPreferencesChangedNotificationWithUserInfo:@{ MKPreferencesResetLearningKey: @YES }];
}

- (BOOL)hasPendingLearningReset {
    return [self.defaults stringForKey:MKUserDefaultLearningResetRequestKey].length > 0;
}

- (void)clearPendingLearningReset {
    if (![self hasPendingLearningReset]) {
        return;
    }
    [self.defaults removeObjectForKey:MKUserDefaultLearningResetRequestKey];
    [self.defaults synchronize];
}

- (void)postPreferencesChangedNotification {
    [self postPreferencesChangedNotificationWithUserInfo:nil];
}

- (void)postPreferencesChangedNotificationWithUserInfo:(NSDictionary *)userInfo {
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:MKPreferencesDidChangeNotification
                                                                  object:nil
                                                                userInfo:userInfo
                                                      deliverImmediately:YES];
}

- (NSString *)userDefaultShortcutKeyForMode:(MKInputMode)mode {
    if ([mode isEqualToString:MKInputModeSucheng]) {
        return MKUserDefaultSuchengShortcutKey;
    }
    if ([mode isEqualToString:MKInputModeSmartSucheng]) {
        return MKUserDefaultSmartSuchengShortcutKey;
    }
    if ([mode isEqualToString:MKInputModeCangjie]) {
        return MKUserDefaultCangjieShortcutKey;
    }
    if ([mode isEqualToString:MKInputModePinyin]) {
        return MKUserDefaultPinyinShortcutKey;
    }
    return MKUserDefaultSuchengShortcutKey;
}

- (MKInputMode)fallbackEngineModeForEnabledModes:(NSArray<NSString *> *)enabledModes {
    return [PurrTypeInputBehavior firstEnabledInputModeInModes:enabledModes] ?: MKInputModeSucheng;
}

- (NSDictionary<NSString *, id> *)modeOverridesForKey:(NSString *)key {
    id value = [self.defaults objectForKey:key];
    return [value isKindOfClass:[NSDictionary class]] ? value : @{};
}

- (void)setModeOverrideValue:(id)value forMode:(MKInputMode)mode key:(NSString *)key {
    if (![self isSupportedEngineMode:mode] || key.length == 0) {
        return;
    }

    NSMutableDictionary<NSString *, id> *overrides = [[self modeOverridesForKey:key] mutableCopy];
    if (value) {
        overrides[mode] = value;
    } else {
        [overrides removeObjectForKey:mode];
    }

    if (overrides.count > 0) {
        [self.defaults setObject:overrides forKey:key];
    } else {
        [self.defaults removeObjectForKey:key];
    }
    [self.defaults synchronize];
}

- (NSString *)normalizedSpaceKeyOverride:(NSString *)overrideValue {
    if ([overrideValue isEqualToString:MKModeSpaceKeyCommitFirst] ||
        [overrideValue isEqualToString:MKModeSpaceKeyPageCandidates]) {
        return overrideValue;
    }
    return MKModeOverrideFollowGlobal;
}

- (NSString *)normalizedRawEnglishCandidatePosition:(NSString *)position {
    if ([position isEqualToString:MKRawEnglishCandidatePositionTrailing]) {
        return MKRawEnglishCandidatePositionTrailing;
    }
    return MKRawEnglishCandidatePositionLeading;
}

- (NSString *)normalizedCandidatePanelOrientation:(NSString *)orientation {
    if ([orientation isEqualToString:MKCandidatePanelOrientationHorizontal]) {
        return MKCandidatePanelOrientationHorizontal;
    }
    return MKCandidatePanelOrientationVertical;
}

- (CGFloat)normalizedCandidatePanelFontSize:(CGFloat)fontSize {
    if (fontSize <= 15.5) {
        return 15.0;
    }
    if (fontSize >= 18.5) {
        return 19.0;
    }
    return 17.0;
}

- (NSString *)normalizedCandidatePanelHighlightColor:(NSString *)highlightColor {
    if ([highlightColor isEqualToString:MKCandidatePanelHighlightOrange] ||
        [highlightColor isEqualToString:MKCandidatePanelHighlightYellow] ||
        [highlightColor isEqualToString:MKCandidatePanelHighlightGreen] ||
        [highlightColor isEqualToString:MKCandidatePanelHighlightBlue] ||
        [highlightColor isEqualToString:MKCandidatePanelHighlightPurple] ||
        [highlightColor isEqualToString:MKCandidatePanelHighlightPink]) {
        return highlightColor;
    }
    if ([highlightColor hasPrefix:MKCandidatePanelHighlightCustomPrefix]) {
        NSString *hex = [highlightColor substringFromIndex:MKCandidatePanelHighlightCustomPrefix.length];
        if ([hex hasPrefix:@"#"]) {
            hex = [hex substringFromIndex:1];
        }
        if (hex.length == 6) {
            unsigned int rgb = 0;
            NSScanner *scanner = [NSScanner scannerWithString:hex];
            if ([scanner scanHexInt:&rgb] && scanner.isAtEnd) {
                return [NSString stringWithFormat:@"%@#%06X",
                                                  MKCandidatePanelHighlightCustomPrefix,
                                                  rgb & 0xFFFFFF];
            }
        }
    }
    return MKCandidatePanelHighlightRed;
}

- (NSString *)normalizedVoiceRecognitionLocaleIdentifier:(NSString *)localeIdentifier {
    NSString *canonical = [[[localeIdentifier ?: @"" stringByReplacingOccurrencesOfString:@"_" withString:@"-"] lowercaseString] copy];
    if ([canonical isEqualToString:@"zh-hk"]) {
        return MKVoiceRecognitionLocaleZhHK;
    }
    if ([canonical isEqualToString:@"zh-tw"]) {
        return MKVoiceRecognitionLocaleZhTW;
    }
    return MKVoiceRecognitionLocaleAuto;
}

@end
