#import "PurrTypeInputBehavior.h"
#import <AppKit/AppKit.h>

static const NSInteger MKInputBehaviorKeyCodeComma = 43;
static const NSInteger MKInputBehaviorKeyCodeBackslash = 42;
static const NSInteger MKInputBehaviorKeyCodeBacktick = 50;
static const NSInteger MKInputBehaviorKeyCodeReturn = 36;
static const NSInteger MKInputBehaviorKeyCodeTab = 48;
static const NSInteger MKInputBehaviorKeyCodeSpace = 49;
static const NSInteger MKInputBehaviorKeyCodeDelete = 51;
static const NSInteger MKInputBehaviorKeyCodeEscape = 53;
static const NSInteger MKInputBehaviorKeyCodeKeypadEnter = 76;
static const NSInteger MKInputBehaviorKeyCodePageUp = 116;
static const NSInteger MKInputBehaviorKeyCodePageDown = 121;
static const NSInteger MKInputBehaviorKeyCodeLeftArrow = 123;
static const NSInteger MKInputBehaviorKeyCodeRightArrow = 124;
static const NSUInteger MKInputBehaviorModeShortcutModifierMask = NSEventModifierFlagControl | NSEventModifierFlagShift;
static const NSUInteger MKInputBehaviorPreferencesShortcutModifierMask = NSEventModifierFlagControl | NSEventModifierFlagShift;
static const NSUInteger MKInputBehaviorCandidatePageSize = 9;
static NSString *const MKShortcutSpecNone = @"none";
static NSString *const MKShortcutSpecLegacyDoubleBacktick = @"double_backtick";
static NSString *const MKShortcutSpecDoubleTapPrefix = @"doubletap:";
static NSString *const MKShortcutSpecControlShiftBacktick = @"ctrl_shift_backtick";
static NSString *const MKShortcutSpecControlShift1 = @"ctrl_shift_1";
static NSString *const MKShortcutSpecControlShift2 = @"ctrl_shift_2";
static NSString *const MKShortcutSpecControlShift3 = @"ctrl_shift_3";
static NSString *const MKShortcutSpecControlShift4 = @"ctrl_shift_4";
static NSString *const MKShortcutSpecControlShift5 = @"ctrl_shift_5";
static NSString *const MKShortcutSpecControlShift6 = @"ctrl_shift_6";
static NSString *const MKShortcutSpecControlShift7 = @"ctrl_shift_7";
static NSString *const MKShortcutSpecControlShift8 = @"ctrl_shift_8";
static NSString *const MKShortcutSpecControlShift9 = @"ctrl_shift_9";
static NSString *const MKShortcutSpecKeyCodePrefix = @"keycode:";
static const NSUInteger MKShortcutModifierBitControl = 1 << 0;
static const NSUInteger MKShortcutModifierBitOption = 1 << 1;
static const NSUInteger MKShortcutModifierBitShift = 1 << 2;
static const NSUInteger MKShortcutModifierBitCommand = 1 << 3;
static const NSInteger MKShortcutDoubleTapDefaultIntervalMS = 500;

static NSUInteger MKShortcutModifierBitsFromEventFlags(NSUInteger flags) {
    NSUInteger relevantFlags = flags & NSEventModifierFlagDeviceIndependentFlagsMask;
    NSUInteger bits = 0;
    if ((relevantFlags & NSEventModifierFlagControl) != 0) {
        bits |= MKShortcutModifierBitControl;
    }
    if ((relevantFlags & NSEventModifierFlagOption) != 0) {
        bits |= MKShortcutModifierBitOption;
    }
    if ((relevantFlags & NSEventModifierFlagShift) != 0) {
        bits |= MKShortcutModifierBitShift;
    }
    if ((relevantFlags & NSEventModifierFlagCommand) != 0) {
        bits |= MKShortcutModifierBitCommand;
    }
    return bits;
}

static NSUInteger MKEventFlagsFromShortcutModifierBits(NSUInteger bits) {
    NSUInteger flags = 0;
    if ((bits & MKShortcutModifierBitControl) != 0) {
        flags |= NSEventModifierFlagControl;
    }
    if ((bits & MKShortcutModifierBitOption) != 0) {
        flags |= NSEventModifierFlagOption;
    }
    if ((bits & MKShortcutModifierBitShift) != 0) {
        flags |= NSEventModifierFlagShift;
    }
    if ((bits & MKShortcutModifierBitCommand) != 0) {
        flags |= NSEventModifierFlagCommand;
    }
    return flags;
}

static BOOL MKShortcutModifierBitsAreSupported(NSUInteger bits) {
    if ((bits & MKShortcutModifierBitCommand) != 0) {
        return NO;
    }
    return (bits & (MKShortcutModifierBitControl | MKShortcutModifierBitOption)) != 0;
}

static BOOL MKParseKeyCodeShortcutSpec(NSString *spec, NSUInteger *modifierBits, NSInteger *keyCode) {
    if (![spec hasPrefix:MKShortcutSpecKeyCodePrefix]) {
        return NO;
    }
    NSString *payload = [spec substringFromIndex:MKShortcutSpecKeyCodePrefix.length];
    NSArray<NSString *> *parts = [payload componentsSeparatedByString:@":"];
    if (parts.count != 2) {
        return NO;
    }
    NSInteger parsedBits = parts[0].integerValue;
    NSInteger parsedKeyCode = parts[1].integerValue;
    if (parsedBits <= 0 || parsedKeyCode < 0 || !MKShortcutModifierBitsAreSupported((NSUInteger)parsedBits)) {
        return NO;
    }
    if (modifierBits) {
        *modifierBits = (NSUInteger)parsedBits;
    }
    if (keyCode) {
        *keyCode = parsedKeyCode;
    }
    return YES;
}

static NSString *MKDoubleTapShortcutSpec(NSInteger keyCode, NSInteger intervalMS) {
    return [NSString stringWithFormat:@"%@%ld:%ld",
            MKShortcutSpecDoubleTapPrefix,
            (long)keyCode,
            (long)intervalMS];
}

static BOOL MKParseDoubleTapShortcutSpec(NSString *spec, NSInteger *keyCode, NSInteger *intervalMS) {
    if ([spec isEqualToString:MKShortcutSpecLegacyDoubleBacktick]) {
        if (keyCode) {
            *keyCode = MKInputBehaviorKeyCodeBacktick;
        }
        if (intervalMS) {
            *intervalMS = MKShortcutDoubleTapDefaultIntervalMS;
        }
        return YES;
    }

    if (![spec hasPrefix:MKShortcutSpecDoubleTapPrefix]) {
        return NO;
    }

    NSString *payload = [spec substringFromIndex:MKShortcutSpecDoubleTapPrefix.length];
    NSArray<NSString *> *parts = [payload componentsSeparatedByString:@":"];
    if (parts.count != 2) {
        return NO;
    }

    NSInteger parsedKeyCode = parts[0].integerValue;
    NSInteger parsedIntervalMS = parts[1].integerValue;
    if (parsedKeyCode < 0 || parsedIntervalMS < 100 || parsedIntervalMS > 2000) {
        return NO;
    }
    if (keyCode) {
        *keyCode = parsedKeyCode;
    }
    if (intervalMS) {
        *intervalMS = parsedIntervalMS;
    }
    return YES;
}

static NSString *MKCanonicalInputMode(NSString *mode) {
    if ([mode isEqualToString:MKInputModeSucheng] || [mode isEqualToString:@"sucheng"]) {
        return MKInputModeSucheng;
    }
    if ([mode isEqualToString:MKInputModeSmartSucheng] ||
        [mode isEqualToString:@"newSucheng"] ||
        [mode isEqualToString:@"new_sucheng"] ||
        [mode isEqualToString:@"smartSucheng"]) {
        return MKInputModeSmartSucheng;
    }
    if ([mode isEqualToString:MKInputModeCangjie]) {
        return MKInputModeCangjie;
    }
    if ([mode isEqualToString:MKInputModePinyin]) {
        return MKInputModePinyin;
    }
    return nil;
}

static NSString *MKKeyDisplayNameForKeyCode(NSInteger keyCode) {
    static NSDictionary<NSNumber *, NSString *> *names = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        names = @{
            @0: @"A", @1: @"S", @2: @"D", @3: @"F", @4: @"H", @5: @"G",
            @6: @"Z", @7: @"X", @8: @"C", @9: @"V", @11: @"B",
            @12: @"Q", @13: @"W", @14: @"E", @15: @"R", @16: @"Y", @17: @"T",
            @18: @"1", @19: @"2", @20: @"3", @21: @"4", @22: @"6", @23: @"5",
            @24: @"=", @25: @"9", @26: @"7", @27: @"-", @28: @"8", @29: @"0",
            @30: @"]", @31: @"O", @32: @"U", @33: @"[", @34: @"I", @35: @"P",
            @36: @"Return", @37: @"L", @38: @"J", @39: @"'", @40: @"K", @41: @";",
            @42: @"Backslash", @43: @",", @44: @"/", @45: @"N", @46: @"M", @47: @".",
            @48: @"Tab", @49: @"Space", @50: @"`", @51: @"Delete", @53: @"Escape",
            @76: @"Enter", @116: @"Page Up", @121: @"Page Down",
            @123: @"Left Arrow", @124: @"Right Arrow", @125: @"Down Arrow", @126: @"Up Arrow"
        };
    });
    return names[@(keyCode)];
}

static NSString *MKKeyEquivalentForKeyCode(NSInteger keyCode) {
    static NSDictionary<NSNumber *, NSString *> *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @{
            @0: @"a", @1: @"s", @2: @"d", @3: @"f", @4: @"h", @5: @"g",
            @6: @"z", @7: @"x", @8: @"c", @9: @"v", @11: @"b",
            @12: @"q", @13: @"w", @14: @"e", @15: @"r", @16: @"y", @17: @"t",
            @18: @"1", @19: @"2", @20: @"3", @21: @"4", @22: @"6", @23: @"5",
            @24: @"=", @25: @"9", @26: @"7", @27: @"-", @28: @"8", @29: @"0",
            @30: @"]", @31: @"o", @32: @"u", @33: @"[", @34: @"i", @35: @"p",
            @37: @"l", @38: @"j", @39: @"'", @40: @"k", @41: @";",
            @42: @"\\", @43: @",", @44: @"/", @45: @"n", @46: @"m", @47: @".",
            @48: @"\t", @49: @" ", @50: @"`", @51: @"\b", @53: @"\033", @76: @"\r"
        };
    });
    return keys[@(keyCode)] ?: @"";
}

@implementation PurrTypeInputBehavior

+ (NSUInteger)candidatePageSize {
    return MKInputBehaviorCandidatePageSize;
}

+ (NSArray<MKInputMode> *)orderedInputModes {
    return @[MKInputModeSucheng, MKInputModeSmartSucheng, MKInputModeCangjie, MKInputModePinyin];
}

+ (NSArray<MKInputMode> *)defaultEnabledInputModes {
    return [self orderedInputModes];
}

+ (NSArray<MKInputMode> *)normalizedEnabledInputModes:(NSArray<NSString *> *)inputModes {
    NSMutableSet<NSString *> *requestedModes = [NSMutableSet set];
    if ([inputModes isKindOfClass:[NSArray class]]) {
        for (id value in inputModes) {
            if (![value isKindOfClass:[NSString class]]) {
                continue;
            }
            NSString *canonicalMode = MKCanonicalInputMode((NSString *)value);
            if (canonicalMode.length > 0) {
                [requestedModes addObject:canonicalMode];
            }
        }
    }

    if (requestedModes.count == 0) {
        return [self defaultEnabledInputModes];
    }

    NSMutableArray<MKInputMode> *normalizedModes = [NSMutableArray arrayWithCapacity:requestedModes.count];
    for (MKInputMode mode in [self orderedInputModes]) {
        if ([requestedModes containsObject:mode]) {
            [normalizedModes addObject:mode];
        }
    }
    return normalizedModes.count > 0 ? normalizedModes : [self defaultEnabledInputModes];
}

+ (nullable MKInputMode)firstEnabledInputModeInModes:(NSArray<NSString *> *)inputModes {
    return [self normalizedEnabledInputModes:inputModes].firstObject;
}

+ (BOOL)inputMode:(MKInputMode)mode isEnabledInModes:(NSArray<NSString *> *)inputModes {
    NSString *canonicalMode = MKCanonicalInputMode(mode);
    if (canonicalMode.length == 0) {
        return NO;
    }
    return [[self normalizedEnabledInputModes:inputModes] containsObject:canonicalMode];
}

+ (nullable MKInputMode)modeForShortcutKeyCode:(NSInteger)keyCode modifiers:(NSUInteger)flags {
    NSDictionary<NSString *, NSString *> *defaults = @{
        MKInputModeSucheng: [self defaultModeShortcutSpecForMode:MKInputModeSucheng],
        MKInputModeSmartSucheng: [self defaultModeShortcutSpecForMode:MKInputModeSmartSucheng],
        MKInputModeCangjie: [self defaultModeShortcutSpecForMode:MKInputModeCangjie],
        MKInputModePinyin: [self defaultModeShortcutSpecForMode:MKInputModePinyin]
    };
    return [self modeForShortcutKeyCode:keyCode modifiers:flags shortcutsByMode:defaults];
}

+ (nullable MKInputMode)modeForShortcutKeyCode:(NSInteger)keyCode
                                     modifiers:(NSUInteger)flags
                               shortcutsByMode:(NSDictionary<NSString *, NSString *> *)shortcutsByMode {
    return [self modeForShortcutKeyCode:keyCode
                              modifiers:flags
                        shortcutsByMode:shortcutsByMode
                            enabledModes:[self orderedInputModes]];
}

+ (nullable MKInputMode)modeForShortcutKeyCode:(NSInteger)keyCode
                                     modifiers:(NSUInteger)flags
                               shortcutsByMode:(NSDictionary<NSString *, NSString *> *)shortcutsByMode
                                  enabledModes:(NSArray<NSString *> *)enabledModes {
    NSArray<MKInputMode> *modes = [self normalizedEnabledInputModes:enabledModes];
    for (MKInputMode mode in modes) {
        NSString *shortcutSpec = shortcutsByMode[mode] ?: [self defaultModeShortcutSpecForMode:mode];
        if ([self shortcutSpec:shortcutSpec matchesKeyCode:keyCode modifiers:flags]) {
            return mode;
        }
    }
    return nil;
}

+ (BOOL)isPreferencesShortcutKeyCode:(NSInteger)keyCode modifiers:(NSUInteger)flags {
    NSUInteger relevantFlags = flags & NSEventModifierFlagDeviceIndependentFlagsMask;
    return keyCode == MKInputBehaviorKeyCodeComma &&
           (relevantFlags & MKInputBehaviorPreferencesShortcutModifierMask) == MKInputBehaviorPreferencesShortcutModifierMask &&
           (relevantFlags & (NSEventModifierFlagCommand | NSEventModifierFlagOption)) == 0;
}

+ (BOOL)privacyLockShouldPauseLearningContextForMode:(MKInputMode)mode enabled:(BOOL)enabled {
    return enabled && [mode isEqualToString:MKInputModeSmartSucheng];
}

+ (NSString *)defaultSwitchInputModeShortcutSpec {
    return [NSString stringWithFormat:@"%@%lu:%ld",
            MKShortcutSpecKeyCodePrefix,
            (unsigned long)MKShortcutModifierBitControl,
            (long)MKInputBehaviorKeyCodeBackslash];
}

+ (NSString *)defaultModeShortcutSpecForMode:(MKInputMode)mode {
    if ([mode isEqualToString:MKInputModeSucheng]) {
        return MKShortcutSpecControlShift1;
    }
    if ([mode isEqualToString:MKInputModeSmartSucheng]) {
        return MKShortcutSpecControlShift2;
    }
    if ([mode isEqualToString:MKInputModeCangjie]) {
        return MKShortcutSpecControlShift3;
    }
    if ([mode isEqualToString:MKInputModePinyin]) {
        return MKShortcutSpecControlShift4;
    }
    return MKShortcutSpecNone;
}

+ (NSString *)defaultPrivacyLockShortcutSpec {
    return MKDoubleTapShortcutSpec(MKInputBehaviorKeyCodeBacktick, MKShortcutDoubleTapDefaultIntervalMS);
}

+ (NSArray<NSString *> *)availableModeShortcutSpecs {
    return @[
        MKShortcutSpecNone,
        MKShortcutSpecControlShift1,
        MKShortcutSpecControlShift2,
        MKShortcutSpecControlShift3,
        MKShortcutSpecControlShift4,
        MKShortcutSpecControlShift5,
        MKShortcutSpecControlShift6,
        MKShortcutSpecControlShift7,
        MKShortcutSpecControlShift8,
        MKShortcutSpecControlShift9
    ];
}

+ (NSArray<NSString *> *)availablePrivacyLockShortcutSpecs {
    return @[[self defaultPrivacyLockShortcutSpec], MKShortcutSpecLegacyDoubleBacktick, MKShortcutSpecControlShiftBacktick, MKShortcutSpecNone];
}

+ (nullable NSString *)shortcutSpecForKeyCode:(NSInteger)keyCode modifiers:(NSUInteger)flags {
    NSUInteger bits = MKShortcutModifierBitsFromEventFlags(flags);
    if (!MKShortcutModifierBitsAreSupported(bits) || keyCode < 0 || MKKeyDisplayNameForKeyCode(keyCode).length == 0) {
        return nil;
    }

    if (bits == (MKShortcutModifierBitControl | MKShortcutModifierBitShift)) {
        if (keyCode == MKInputBehaviorKeyCodeBacktick) {
            return MKShortcutSpecControlShiftBacktick;
        }
        NSDictionary<NSNumber *, NSString *> *legacyModeSpecs = @{
            @18: MKShortcutSpecControlShift1,
            @19: MKShortcutSpecControlShift2,
            @20: MKShortcutSpecControlShift3,
            @21: MKShortcutSpecControlShift4,
            @23: MKShortcutSpecControlShift5,
            @22: MKShortcutSpecControlShift6,
            @26: MKShortcutSpecControlShift7,
            @28: MKShortcutSpecControlShift8,
            @25: MKShortcutSpecControlShift9
        };
        NSString *legacySpec = legacyModeSpecs[@(keyCode)];
        if (legacySpec.length > 0) {
            return legacySpec;
        }
    }

    return [NSString stringWithFormat:@"%@%lu:%ld", MKShortcutSpecKeyCodePrefix, (unsigned long)bits, (long)keyCode];
}

+ (NSString *)normalizedSwitchInputModeShortcutSpec:(NSString *)shortcutSpec {
    if ([shortcutSpec isEqualToString:MKShortcutSpecNone]) {
        return MKShortcutSpecNone;
    }
    NSUInteger bits = 0;
    NSInteger keyCode = -1;
    if (MKParseKeyCodeShortcutSpec(shortcutSpec ?: @"", &bits, &keyCode) && MKKeyDisplayNameForKeyCode(keyCode).length > 0) {
        return shortcutSpec;
    }
    return [self defaultSwitchInputModeShortcutSpec];
}

+ (NSString *)normalizedModeShortcutSpec:(NSString *)shortcutSpec forMode:(MKInputMode)mode {
    NSSet<NSString *> *available = [NSSet setWithArray:[self availableModeShortcutSpecs]];
    if ([available containsObject:shortcutSpec ?: @""]) {
        return shortcutSpec;
    }
    NSUInteger bits = 0;
    NSInteger keyCode = -1;
    if (MKParseKeyCodeShortcutSpec(shortcutSpec ?: @"", &bits, &keyCode) && MKKeyDisplayNameForKeyCode(keyCode).length > 0) {
        return shortcutSpec;
    }
    return [self defaultModeShortcutSpecForMode:mode];
}

+ (NSString *)normalizedPrivacyLockShortcutSpec:(NSString *)shortcutSpec {
    NSSet<NSString *> *available = [NSSet setWithArray:[self availablePrivacyLockShortcutSpecs]];
    if ([available containsObject:shortcutSpec ?: @""]) {
        if ([shortcutSpec isEqualToString:MKShortcutSpecLegacyDoubleBacktick]) {
            return [self defaultPrivacyLockShortcutSpec];
        }
        return shortcutSpec;
    }
    NSInteger doubleTapKeyCode = -1;
    NSInteger intervalMS = 0;
    if (MKParseDoubleTapShortcutSpec(shortcutSpec ?: @"", &doubleTapKeyCode, &intervalMS) &&
        MKKeyDisplayNameForKeyCode(doubleTapKeyCode).length > 0) {
        return MKDoubleTapShortcutSpec(doubleTapKeyCode, intervalMS);
    }
    NSUInteger bits = 0;
    NSInteger keyCode = -1;
    if (MKParseKeyCodeShortcutSpec(shortcutSpec ?: @"", &bits, &keyCode) && MKKeyDisplayNameForKeyCode(keyCode).length > 0) {
        return shortcutSpec;
    }
    return [self defaultPrivacyLockShortcutSpec];
}

+ (NSString *)displayNameForShortcutSpec:(NSString *)shortcutSpec {
    NSString *spec = shortcutSpec ?: MKShortcutSpecNone;
    if ([spec isEqualToString:MKShortcutSpecNone]) {
        return @"None";
    }
    NSInteger doubleTapKeyCode = -1;
    NSInteger intervalMS = 0;
    if (MKParseDoubleTapShortcutSpec(spec, &doubleTapKeyCode, &intervalMS)) {
        (void)intervalMS;
        NSString *keyName = MKKeyDisplayNameForKeyCode(doubleTapKeyCode);
        if (doubleTapKeyCode == MKInputBehaviorKeyCodeBacktick) {
            return @"Double `";
        }
        return keyName.length > 0 ? [NSString stringWithFormat:@"Double %@", keyName] : @"None";
    }
    if ([spec isEqualToString:MKShortcutSpecControlShiftBacktick]) {
        return @"Control+Shift+`";
    }

    NSDictionary<NSString *, NSString *> *displayNames = @{
        MKShortcutSpecControlShift1: @"Control+Shift+1",
        MKShortcutSpecControlShift2: @"Control+Shift+2",
        MKShortcutSpecControlShift3: @"Control+Shift+3",
        MKShortcutSpecControlShift4: @"Control+Shift+4",
        MKShortcutSpecControlShift5: @"Control+Shift+5",
        MKShortcutSpecControlShift6: @"Control+Shift+6",
        MKShortcutSpecControlShift7: @"Control+Shift+7",
        MKShortcutSpecControlShift8: @"Control+Shift+8",
        MKShortcutSpecControlShift9: @"Control+Shift+9"
    };
    NSString *legacyName = displayNames[spec];
    if (legacyName.length > 0) {
        return legacyName;
    }

    NSUInteger bits = 0;
    NSInteger keyCode = -1;
    if (!MKParseKeyCodeShortcutSpec(spec, &bits, &keyCode)) {
        return @"None";
    }

    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:4];
    if ((bits & MKShortcutModifierBitControl) != 0) {
        [parts addObject:@"Control"];
    }
    if ((bits & MKShortcutModifierBitOption) != 0) {
        [parts addObject:@"Option"];
    }
    if ((bits & MKShortcutModifierBitShift) != 0) {
        [parts addObject:@"Shift"];
    }
    NSString *keyName = MKKeyDisplayNameForKeyCode(keyCode);
    if (keyName.length == 0) {
        return @"None";
    }
    [parts addObject:keyName];
    return [parts componentsJoinedByString:@"+"];
}

+ (NSString *)keyEquivalentForShortcutSpec:(NSString *)shortcutSpec {
    NSDictionary<NSString *, NSString *> *keyEquivalents = @{
        MKShortcutSpecControlShiftBacktick: @"`",
        MKShortcutSpecControlShift1: @"1",
        MKShortcutSpecControlShift2: @"2",
        MKShortcutSpecControlShift3: @"3",
        MKShortcutSpecControlShift4: @"4",
        MKShortcutSpecControlShift5: @"5",
        MKShortcutSpecControlShift6: @"6",
        MKShortcutSpecControlShift7: @"7",
        MKShortcutSpecControlShift8: @"8",
        MKShortcutSpecControlShift9: @"9"
    };
    NSString *keyEquivalent = keyEquivalents[shortcutSpec ?: @""];
    if (keyEquivalent.length > 0) {
        return keyEquivalent;
    }
    NSUInteger bits = 0;
    NSInteger keyCode = -1;
    if (MKParseKeyCodeShortcutSpec(shortcutSpec ?: @"", &bits, &keyCode)) {
        return MKKeyEquivalentForKeyCode(keyCode);
    }
    return @"";
}

+ (NSUInteger)keyEquivalentModifierMaskForShortcutSpec:(NSString *)shortcutSpec {
    if ([self keyEquivalentForShortcutSpec:shortcutSpec].length == 0) {
        return 0;
    }
    NSUInteger bits = 0;
    NSInteger keyCode = -1;
    if (MKParseKeyCodeShortcutSpec(shortcutSpec ?: @"", &bits, &keyCode)) {
        (void)keyCode;
        return MKEventFlagsFromShortcutModifierBits(bits);
    }
    return MKInputBehaviorModeShortcutModifierMask;
}

+ (BOOL)shortcutSpec:(NSString *)shortcutSpec matchesKeyCode:(NSInteger)keyCode modifiers:(NSUInteger)flags {
    NSString *spec = shortcutSpec ?: MKShortcutSpecNone;
    NSInteger doubleTapKeyCode = -1;
    NSInteger intervalMS = 0;
    if ([spec isEqualToString:MKShortcutSpecNone] ||
        MKParseDoubleTapShortcutSpec(spec, &doubleTapKeyCode, &intervalMS)) {
        return NO;
    }

    NSUInteger relevantFlags = flags & NSEventModifierFlagDeviceIndependentFlagsMask;
    NSUInteger bits = 0;
    NSInteger customKeyCode = -1;
    if (MKParseKeyCodeShortcutSpec(spec, &bits, &customKeyCode)) {
        return customKeyCode == keyCode &&
               MKShortcutModifierBitsFromEventFlags(relevantFlags) == bits;
    }

    if ((relevantFlags & MKInputBehaviorModeShortcutModifierMask) != MKInputBehaviorModeShortcutModifierMask ||
        (relevantFlags & (NSEventModifierFlagCommand | NSEventModifierFlagOption)) != 0) {
        return NO;
    }

    NSDictionary<NSString *, NSNumber *> *keyCodes = @{
        MKShortcutSpecControlShiftBacktick: @(MKInputBehaviorKeyCodeBacktick),
        MKShortcutSpecControlShift1: @18,
        MKShortcutSpecControlShift2: @19,
        MKShortcutSpecControlShift3: @20,
        MKShortcutSpecControlShift4: @21,
        MKShortcutSpecControlShift5: @23,
        MKShortcutSpecControlShift6: @22,
        MKShortcutSpecControlShift7: @26,
        MKShortcutSpecControlShift8: @28,
        MKShortcutSpecControlShift9: @25
    };
    NSNumber *expectedKeyCode = keyCodes[spec];
    return expectedKeyCode != nil && expectedKeyCode.integerValue == keyCode;
}

+ (BOOL)shortcutSpec:(NSString *)firstShortcutSpec conflictsWithShortcutSpec:(NSString *)secondShortcutSpec {
    NSString *first = firstShortcutSpec ?: MKShortcutSpecNone;
    NSString *second = secondShortcutSpec ?: MKShortcutSpecNone;
    if ([first isEqualToString:MKShortcutSpecNone] || [second isEqualToString:MKShortcutSpecNone]) {
        return NO;
    }
    NSInteger firstDoubleTapKeyCode = -1;
    NSInteger firstIntervalMS = 0;
    NSInteger secondDoubleTapKeyCode = -1;
    NSInteger secondIntervalMS = 0;
    BOOL firstIsDoubleTap = MKParseDoubleTapShortcutSpec(first, &firstDoubleTapKeyCode, &firstIntervalMS);
    BOOL secondIsDoubleTap = MKParseDoubleTapShortcutSpec(second, &secondDoubleTapKeyCode, &secondIntervalMS);
    if (firstIsDoubleTap || secondIsDoubleTap) {
        return firstIsDoubleTap && secondIsDoubleTap && firstDoubleTapKeyCode == secondDoubleTapKeyCode;
    }

    NSArray<NSNumber *> *keyCodes = @[@0, @1, @2, @3, @4, @5, @6, @7, @8, @9, @11, @12, @13, @14, @15, @16, @17,
                                      @18, @19, @20, @21, @22, @23, @24, @25, @26, @27, @28, @29, @30, @31, @32,
                                      @33, @34, @35, @36, @37, @38, @39, @40, @41, @42, @43, @44, @45, @46, @47,
                                      @48, @49, @50, @51, @53, @76, @116, @121, @123, @124, @125, @126];
    NSArray<NSNumber *> *modifierMasks = @[
        @(NSEventModifierFlagControl),
        @(NSEventModifierFlagControl | NSEventModifierFlagShift),
        @(NSEventModifierFlagOption),
        @(NSEventModifierFlagOption | NSEventModifierFlagShift),
        @(NSEventModifierFlagControl | NSEventModifierFlagOption),
        @(NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagShift)
    ];

    for (NSNumber *keyCodeNumber in keyCodes) {
        NSInteger keyCode = keyCodeNumber.integerValue;
        for (NSNumber *modifierMaskNumber in modifierMasks) {
            NSUInteger modifierMask = modifierMaskNumber.unsignedIntegerValue;
            if ([self shortcutSpec:first matchesKeyCode:keyCode modifiers:modifierMask] &&
                [self shortcutSpec:second matchesKeyCode:keyCode modifiers:modifierMask]) {
                return YES;
            }
        }
    }
    return NO;
}

+ (BOOL)isDoubleBacktickShortcutSpec:(NSString *)shortcutSpec {
    NSInteger keyCode = -1;
    NSInteger intervalMS = 0;
    return MKParseDoubleTapShortcutSpec(shortcutSpec ?: @"", &keyCode, &intervalMS) &&
           keyCode == MKInputBehaviorKeyCodeBacktick;
}

+ (BOOL)isBacktickKeyCode:(NSInteger)keyCode inputString:(NSString *)string modifiers:(NSUInteger)flags {
    NSUInteger relevantFlags = flags & NSEventModifierFlagDeviceIndependentFlagsMask;
    if ((relevantFlags & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption)) != 0) {
        return NO;
    }
    return keyCode == MKInputBehaviorKeyCodeBacktick || [string isEqualToString:@"`"];
}

+ (NSInteger)candidatePageOffsetForKeyCode:(NSInteger)keyCode
                                 modifiers:(NSUInteger)flags
                            candidateCount:(NSUInteger)candidateCount
                        spacePagingEnabled:(BOOL)spacePagingEnabled {
    return [self candidatePageOffsetForKeyCode:keyCode
                                     modifiers:flags
                                candidateCount:candidateCount
                            spacePagingEnabled:spacePagingEnabled
                             candidatePageSize:MKInputBehaviorCandidatePageSize];
}

+ (NSInteger)candidatePageOffsetForKeyCode:(NSInteger)keyCode
                                 modifiers:(NSUInteger)flags
                            candidateCount:(NSUInteger)candidateCount
                        spacePagingEnabled:(BOOL)spacePagingEnabled
                         candidatePageSize:(NSUInteger)candidatePageSize {
    NSUInteger pageSize = candidatePageSize > 0 ? candidatePageSize : MKInputBehaviorCandidatePageSize;
    if (candidateCount <= pageSize) {
        return 0;
    }

    if (keyCode == MKInputBehaviorKeyCodeSpace && !spacePagingEnabled) {
        return 0;
    }

    if (keyCode == MKInputBehaviorKeyCodePageDown ||
        keyCode == MKInputBehaviorKeyCodeRightArrow ||
        keyCode == MKInputBehaviorKeyCodeSpace) {
        return 1;
    }

    if (keyCode == MKInputBehaviorKeyCodePageUp ||
        keyCode == MKInputBehaviorKeyCodeLeftArrow) {
        return -1;
    }

    if (keyCode == MKInputBehaviorKeyCodeTab) {
        return (flags & NSEventModifierFlagShift) != 0 ? -1 : 1;
    }

    return 0;
}

+ (NSInteger)candidatePageOffsetForSelector:(SEL)selector
                             candidateCount:(NSUInteger)candidateCount
                          candidatePageSize:(NSUInteger)candidatePageSize {
    NSUInteger pageSize = candidatePageSize > 0 ? candidatePageSize : MKInputBehaviorCandidatePageSize;
    if (candidateCount <= pageSize) {
        return 0;
    }

    if (selector == @selector(moveRight:) ||
        selector == @selector(pageDown:) ||
        selector == @selector(scrollPageDown:)) {
        return 1;
    }

    if (selector == @selector(moveLeft:) ||
        selector == @selector(pageUp:) ||
        selector == @selector(scrollPageUp:)) {
        return -1;
    }

    return 0;
}

+ (NSArray<MKCandidate *> *)candidatePageFromPool:(NSArray<MKCandidate *> *)candidatePool
                                       pageIndex:(NSUInteger *)pageIndex {
    return [self candidatePageFromPool:candidatePool pageIndex:pageIndex pageSize:MKInputBehaviorCandidatePageSize];
}

+ (NSArray<MKCandidate *> *)candidatePageFromPool:(NSArray<MKCandidate *> *)candidatePool
                                       pageIndex:(NSUInteger *)pageIndex
                                        pageSize:(NSUInteger)pageSize {
    if (candidatePool.count == 0) {
        if (pageIndex) {
            *pageIndex = 0;
        }
        return @[];
    }

    NSUInteger effectivePageSize = pageSize > 0 ? pageSize : MKInputBehaviorCandidatePageSize;
    NSUInteger pageCount = (candidatePool.count + effectivePageSize - 1) / effectivePageSize;
    NSUInteger effectivePageIndex = pageIndex ? *pageIndex : 0;
    if (effectivePageIndex >= pageCount) {
        effectivePageIndex = pageCount - 1;
        if (pageIndex) {
            *pageIndex = effectivePageIndex;
        }
    }

    NSUInteger start = effectivePageIndex * effectivePageSize;
    NSUInteger length = MIN(effectivePageSize, candidatePool.count - start);
    return [candidatePool subarrayWithRange:NSMakeRange(start, length)];
}

+ (NSUInteger)spellingSuggestionLimitForCandidatePageSize:(NSUInteger)pageSize {
    NSUInteger effectivePageSize = pageSize > 0 ? pageSize : MKInputBehaviorCandidatePageSize;
    return effectivePageSize <= 5 ? 2 : 3;
}

+ (NSArray<MKCandidate *> *)candidatePoolByMergingPrimaryCandidates:(NSArray<MKCandidate *> *)primaryCandidates
                                                spellingCandidates:(NSArray<MKCandidate *> *)spellingCandidates
                                                          pageSize:(NSUInteger)pageSize {
    NSArray<MKCandidate *> *safePrimaryCandidates = primaryCandidates ?: @[];
    NSArray<MKCandidate *> *safeSpellingCandidates = spellingCandidates ?: @[];
    if (safePrimaryCandidates.count == 0 || safeSpellingCandidates.count == 0) {
        return safePrimaryCandidates.count == 0 ? safeSpellingCandidates : safePrimaryCandidates;
    }

    NSUInteger effectivePageSize = pageSize > 0 ? pageSize : MKInputBehaviorCandidatePageSize;
    NSUInteger spellingLimit = MIN(safeSpellingCandidates.count,
                                   [self spellingSuggestionLimitForCandidatePageSize:effectivePageSize]);
    if (spellingLimit == 0) {
        return safePrimaryCandidates;
    }

    NSUInteger visiblePrimaryCount = effectivePageSize > spellingLimit ? effectivePageSize - spellingLimit : 1;
    visiblePrimaryCount = MAX((NSUInteger)1, MIN(visiblePrimaryCount, safePrimaryCandidates.count));

    NSMutableArray<MKCandidate *> *mergedCandidates =
        [NSMutableArray arrayWithCapacity:safePrimaryCandidates.count + spellingLimit];
    [mergedCandidates addObjectsFromArray:[safePrimaryCandidates subarrayWithRange:NSMakeRange(0, visiblePrimaryCount)]];
    [mergedCandidates addObjectsFromArray:[safeSpellingCandidates subarrayWithRange:NSMakeRange(0, spellingLimit)]];
    if (visiblePrimaryCount < safePrimaryCandidates.count) {
        NSRange remainingRange = NSMakeRange(visiblePrimaryCount, safePrimaryCandidates.count - visiblePrimaryCount);
        [mergedCandidates addObjectsFromArray:[safePrimaryCandidates subarrayWithRange:remainingRange]];
    }
    return mergedCandidates;
}

+ (NSString *)displayTextForCandidate:(MKCandidate *)candidate index:(NSUInteger)index {
    if (index < MKInputBehaviorCandidatePageSize) {
        return [NSString stringWithFormat:@"%lu %@", (unsigned long)(index + 1), candidate.text];
    }
    return candidate.text;
}

+ (NSArray<NSString *> *)displayTextsForCandidates:(NSArray<MKCandidate *> *)candidates
                                            buffer:(NSString *)buffer
                              rawEnglishModeActive:(BOOL)rawEnglishModeActive
                             associationModeActive:(BOOL)associationModeActive
                       rawEnglishCandidateEnabled:(BOOL)rawEnglishCandidateEnabled {
    NSMutableArray<NSString *> *candidateTexts = [NSMutableArray arrayWithCapacity:candidates.count + 1];
    if ([self shouldShowRawEnglishCandidateForBuffer:buffer
                              rawEnglishModeActive:rawEnglishModeActive
                              associationModeActive:associationModeActive
                         rawEnglishCandidateEnabled:rawEnglishCandidateEnabled
                                     candidateCount:candidates.count]) {
        [candidateTexts addObject:[self rawEnglishCandidateDisplayTextForBuffer:buffer]];
    }

    NSUInteger index = 0;
    for (MKCandidate *candidate in candidates) {
        [candidateTexts addObject:[self displayTextForCandidate:candidate index:index]];
        index += 1;
    }
    return candidateTexts;
}

+ (BOOL)shouldShowRawEnglishCandidateForBuffer:(NSString *)buffer
                       rawEnglishModeActive:(BOOL)rawEnglishModeActive
                       associationModeActive:(BOOL)associationModeActive
                  rawEnglishCandidateEnabled:(BOOL)rawEnglishCandidateEnabled
                              candidateCount:(NSUInteger)candidateCount {
    return rawEnglishCandidateEnabled &&
           buffer.length > 0 &&
           !rawEnglishModeActive &&
           !associationModeActive &&
           candidateCount > 0 &&
           [self isAsciiCodeString:buffer];
}

+ (NSString *)rawEnglishCandidateDisplayTextForBuffer:(NSString *)buffer {
    if (buffer.length == 0) {
        return @"";
    }
    return [NSString stringWithFormat:@"0 %@", buffer];
}

+ (NSArray<NSString *> *)punctuationCandidateDisplayTextsForString:(NSString *)string {
    if (string.length != 1) {
        return @[];
    }

    NSDictionary<NSString *, NSArray<NSString *> *> *candidateMap = @{
        @"," : @[@",", @"，", @"、"],
        @"." : @[@".", @"。", @"．", @"・", @"…"],
        @"/" : @[@"/", @"／"],
        @";" : @[@";", @"；"],
        @"'" : @[@"'", @"、", @"′", @"‘", @"’", @"‵"],
        @"[" : @[@"[", @"「", @"『", @"《", @"〈", @"〔"],
        @"]" : @[@"]", @"」", @"』", @"》", @"〉", @"〕"],
        @"\\" : @[@"\\", @"＼"],
        @"`" : @[@"`", @"‘", @"‵"],
        @"-" : @[@"-", @"－"],
        @"=" : @[@"=", @"＝"],
        @"<" : @[@"<", @"＜", @"〈", @"《", @"︿", @"︽"],
        @">" : @[@">", @"＞", @"〉", @"》", @"﹀", @"︾"],
        @"?" : @[@"?", @"？"],
        @":" : @[@":", @"："],
        @"\"" : @[@"\"", @"“", @"”", @"〝", @"〞"],
        @"{" : @[@"{", @"｛"],
        @"}" : @[@"}", @"｝"],
        @"|" : @[@"|", @"｜"],
        @"~" : @[@"~", @"～"],
        @"!" : @[@"!", @"！"],
        @"@" : @[@"@", @"＠"],
        @"#" : @[@"#", @"＃"],
        @"$" : @[@"$", @"＄"],
        @"%" : @[@"%", @"％"],
        @"^" : @[@"^", @"︿"],
        @"&" : @[@"&", @"＆"],
        @"*" : @[@"*", @"＊", @"†", @"‡", @"§"],
        @"(" : @[@"(", @"（"],
        @")" : @[@")", @"）"],
        @"_" : @[@"_", @"－", @"＿", @"─", @"–", @"—"],
        @"+" : @[@"+", @"＋", @"＝"]
    };

    NSArray<NSString *> *candidates = candidateMap[string];
    if (candidates.count == 0) {
        return @[];
    }

    NSMutableArray<NSString *> *uniqueCandidates = [NSMutableArray arrayWithCapacity:candidates.count];
    NSMutableSet<NSString *> *seenCandidates = [NSMutableSet setWithCapacity:candidates.count];
    for (NSString *candidate in candidates) {
        if (candidate.length == 0 || [seenCandidates containsObject:candidate]) {
            continue;
        }
        [uniqueCandidates addObject:candidate];
        [seenCandidates addObject:candidate];
    }

    NSMutableArray<NSString *> *displayTexts = [NSMutableArray arrayWithCapacity:uniqueCandidates.count];
    for (NSUInteger index = 0; index < uniqueCandidates.count; index += 1) {
        [displayTexts addObject:[NSString stringWithFormat:@"%lu %@", (unsigned long)(index + 1), uniqueCandidates[index]]];
    }
    return displayTexts;
}

+ (nullable NSString *)punctuationTextForDisplayText:(NSString *)displayText {
    if (displayText.length < 3) {
        return nil;
    }

    unichar number = [displayText characterAtIndex:0];
    if (number < '1' || number > '9' || [displayText characterAtIndex:1] != ' ') {
        return nil;
    }
    return [displayText substringFromIndex:2];
}

+ (BOOL)shouldAutoCommitDefaultPunctuationForInputString:(NSString *)string
                                                keyCode:(NSInteger)keyCode
                                         candidateCount:(NSUInteger)candidateCount {
    if (candidateCount == 0) {
        return NO;
    }

    if (keyCode == MKInputBehaviorKeyCodeEscape ||
        keyCode == MKInputBehaviorKeyCodeDelete ||
        keyCode == MKInputBehaviorKeyCodeReturn ||
        keyCode == MKInputBehaviorKeyCodeKeypadEnter ||
        keyCode == MKInputBehaviorKeyCodeSpace ||
        keyCode == MKInputBehaviorKeyCodeTab) {
        return NO;
    }

    if (string.length == 1) {
        unichar character = [string characterAtIndex:0];
        if (character >= '1' && character <= '9') {
            NSUInteger index = (NSUInteger)(character - '1');
            return index >= candidateCount;
        }
    }

    return YES;
}

+ (BOOL)isShiftOnlyLetterInputWithModifiers:(NSUInteger)flags {
    NSUInteger relevantFlags = flags & NSEventModifierFlagDeviceIndependentFlagsMask;
    return (relevantFlags & NSEventModifierFlagShift) != 0 &&
           (relevantFlags & (NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption)) == 0;
}

+ (BOOL)isAsciiCodeString:(NSString *)string {
    if (string.length == 0) {
        return NO;
    }

    for (NSUInteger index = 0; index < string.length; index += 1) {
        unichar character = [string characterAtIndex:index];
        BOOL isLowercase = character >= 'a' && character <= 'z';
        BOOL isUppercase = character >= 'A' && character <= 'Z';
        if (!isLowercase && !isUppercase) {
            return NO;
        }
    }
    return YES;
}

@end
