#import "PurrTypePreferencesStore.h"
#import "PurrTypeInputBehavior.h"
#import "PurrTypePreferencesConstants.h"

@interface PurrTypePreferencesStore ()

@property(nonatomic, strong) NSUserDefaults *defaults;

- (NSString *)userDefaultShortcutKeyForMode:(MKInputMode)mode;
- (MKInputMode)fallbackEngineModeForEnabledModes:(NSArray<NSString *> *)enabledModes;

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

@end
