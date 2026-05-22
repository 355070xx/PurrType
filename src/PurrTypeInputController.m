#import "PurrTypeInputController.h"
#import "PurrTypeEngine.h"
#import "PurrTypeInputBehavior.h"
#import "PurrTypeInputState.h"
#import "PurrTypeEnglishSpellChecker.h"
#import "PurrTypeCandidatePanel.h"
#import "PurrTypePreferencesWindowController.h"
#import "PurrTypePreferencesConstants.h"
#import "PurrTypePreferencesStore.h"
#import <Carbon/Carbon.h>

static const NSUInteger MKHandledModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagOption;
static const NSInteger MKKeyCodeReturn = 36;
static const NSInteger MKKeyCodeTab = 48;
static const NSInteger MKKeyCodeSpace = 49;
static const NSInteger MKKeyCodeDelete = 51;
static const NSInteger MKKeyCodeEscape = 53;
static const NSInteger MKKeyCodeKeypadEnter = 76;
static const NSInteger MKUnknownKeyCode = -1;
static const NSUInteger MKCandidateFetchLimit = 200;
static const NSUInteger MKAssociationCandidateFetchLimit = 120;
static NSTimeInterval const MKPrivacyLockDoubleBacktickInterval = 0.50;
static NSTimeInterval const MKSecureInputMonitorInterval = 0.25;
static NSInteger const MKModeMenuTagCangjie = 1001;
static NSInteger const MKModeMenuTagSucheng = 1002;
static NSInteger const MKModeMenuTagPinyin = 1003;
static NSInteger const MKModeMenuTagSmartSucheng = 1004;
static NSString *const MKInputSourceUnified = @"org.purrtype.inputmethod.PurrTypeUnified";

static BOOL MKFrontmostApplicationMayOwnSecureTextInputPrompt(void) {
    NSString *bundleIdentifier = [NSWorkspace sharedWorkspace].frontmostApplication.bundleIdentifier ?: @"";
    static NSSet<NSString *> *terminalBundleIdentifiers = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        terminalBundleIdentifiers = [NSSet setWithArray:@[
            @"com.apple.Terminal",
            @"com.googlecode.iterm2",
            @"dev.warp.Warp-Stable",
            @"dev.warp.Warp",
            @"com.mitchellh.ghostty",
            @"net.kovidgoyal.kitty",
            @"org.alacritty",
            @"com.github.wez.wezterm"
        ]];
    });

    return [terminalBundleIdentifiers containsObject:bundleIdentifier];
}

static BOOL MKInputSourceBooleanProperty(TISInputSourceRef source, CFStringRef key) {
    if (!source || !key) {
        return NO;
    }

    CFTypeRef value = TISGetInputSourceProperty(source, key);
    return value && CFGetTypeID(value) == CFBooleanGetTypeID() && CFBooleanGetValue(value);
}

static BOOL MKInputSourceHasIdentifier(TISInputSourceRef source, NSString *identifier) {
    if (!source || identifier.length == 0) {
        return NO;
    }

    CFTypeRef value = TISGetInputSourceProperty(source, kTISPropertyInputSourceID);
    return value && CFGetTypeID(value) == CFStringGetTypeID() && [(__bridge NSString *)value isEqualToString:identifier];
}

static BOOL MKInputSourceIsSelectableASCIIKeyboardSource(TISInputSourceRef source) {
    if (!source || MKInputSourceHasIdentifier(source, MKInputSourceUnified)) {
        return NO;
    }

    return MKInputSourceBooleanProperty(source, kTISPropertyInputSourceIsASCIICapable) &&
           MKInputSourceBooleanProperty(source, kTISPropertyInputSourceIsEnabled) &&
           MKInputSourceBooleanProperty(source, kTISPropertyInputSourceIsSelectCapable);
}

static TISInputSourceRef MKCopySecureTextASCIIInputSource(void) {
    TISInputSourceRef source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource();
    if (MKInputSourceIsSelectableASCIIKeyboardSource(source)) {
        return source;
    }

    if (source) {
        CFRelease(source);
    }
    source = TISCopyCurrentASCIICapableKeyboardInputSource();
    if (MKInputSourceIsSelectableASCIIKeyboardSource(source)) {
        return source;
    }

    if (source) {
        CFRelease(source);
    }
    return NULL;
}

@interface PurrTypeInputController () <PurrTypeCandidatePanelDelegate, PurrTypePreferencesWindowControllerDelegate>

@property(nonatomic, strong) PurrTypeInputState *inputState;
@property(nonatomic, strong) NSArray<MKCandidate *> *candidatePool;
@property(nonatomic, strong) NSArray<MKCandidate *> *currentCandidates;
@property(nonatomic, copy) NSArray<NSString *> *punctuationCandidateTexts;
@property(nonatomic, copy) NSString *punctuationAnchorText;
@property(nonatomic, strong) PurrTypeCandidatePanel *candidatePanel;
@property(nonatomic, strong) PurrTypeEngine *engine;
@property(nonatomic, strong) PurrTypePreferencesStore *preferences;
@property(nonatomic, copy) NSString *engineMode;
@property(nonatomic, copy) NSString *lastCommittedCandidateText;
@property(nonatomic, assign) NSUInteger candidatePageIndex;
@property(nonatomic, assign) NSUInteger selectedCandidateIndex;
@property(nonatomic, assign) NSUInteger candidateUpdateSerial;
@property(nonatomic, assign) BOOL rawEnglishCandidateEnabled;
@property(nonatomic, assign) BOOL spellingSuggestionsEnabled;
@property(nonatomic, assign) BOOL spacePagingEnabled;
@property(nonatomic, assign) BOOL privacyLockEnabled;
@property(nonatomic, assign) NSUInteger candidatePageSize;
@property(nonatomic, copy) NSArray<NSString *> *enabledInputModes;
@property(nonatomic, copy) NSString *switchInputModeShortcut;
@property(nonatomic, copy) NSString *privacyLockShortcut;
@property(nonatomic, copy) NSDictionary<NSString *, NSString *> *modeShortcutsByMode;
@property(nonatomic, assign) NSTimeInterval lastPrivacyLockBacktickTime;
@property(nonatomic, weak) id lastInputClient;
@property(nonatomic, assign) BOOL pendingLearningReset;
@property(nonatomic, strong) NSTimer *secureInputMonitorTimer;
@property(nonatomic, strong) PurrTypeEnglishSpellChecker *englishSpellChecker;

- (void)warmUpEngineInBackground;
- (PurrTypeEngine *)engineForInput;
- (BOOL)effectiveLearningEnabledFromPreferences;
- (BOOL)isSupportedEngineMode:(NSString *)mode;
- (BOOL)isEnabledEngineMode:(NSString *)mode;
- (void)refreshEnabledInputModesFromDefaults;
- (void)setEnabledInputModes:(NSArray<NSString *> *)enabledInputModes;
- (void)switchToEngineMode:(NSString *)mode;
- (void)switchToEngineMode:(NSString *)mode updateClientInputMode:(BOOL)updateClientInputMode client:(id)sender;
- (void)addModeMenuItemWithTitle:(NSString *)title
                            mode:(NSString *)mode
                             tag:(NSInteger)tag
                     shortcutSpec:(NSString *)shortcutSpec
                          toMenu:(NSMenu *)menu;
- (void)addDisabledMenuItemWithTitle:(NSString *)title toMenu:(NSMenu *)menu;
- (NSImage *)modeMenuImageForMode:(NSString *)mode;
- (NSString *)modeDisplayNameForMode:(NSString *)mode;
- (NSString *)learningStatusTitle;
- (BOOL)privacyLockPausesLearningContextForMode:(NSString *)mode;
- (void)resetLearning:(id)sender;
- (void)toggleLearning:(id)sender;
- (void)togglePrivacyLock:(id)sender;
- (void)showPreferences:(id)sender;
- (void)setLearningEnabled:(BOOL)enabled;
- (void)setPrivacyLockEnabled:(BOOL)enabled;
- (void)applyEffectiveLearningState;
- (void)resetLearningStateForPreferenceRequest;
- (void)setRawEnglishCandidateEnabled:(BOOL)enabled;
- (void)setSpellingSuggestionsEnabled:(BOOL)enabled;
- (void)setSpacePagingEnabled:(BOOL)enabled;
- (void)setCandidatePageSize:(NSUInteger)pageSize;
- (void)setSwitchInputModeShortcut:(NSString *)shortcutSpec;
- (void)setPrivacyLockShortcut:(NSString *)shortcutSpec;
- (void)setModeShortcut:(NSString *)shortcutSpec forMode:(NSString *)mode;
- (void)handlePreferencesChanged:(NSNotification *)notification;
- (void)launchPreferencesHelper;
- (id)activeInputClient;
- (void)rememberActiveInputClient:(id)sender;
- (BOOL)handleInputText:(NSString *)string
                    key:(NSInteger)keyCode
              modifiers:(NSUInteger)flags
                 client:(id)sender
            hasKeyEvent:(BOOL)hasKeyEvent;
- (BOOL)handlePreferencesShortcutForKey:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender;
- (BOOL)handleModeShortcutForKey:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender;
- (void)switchToNextEngineMode;
- (BOOL)handlePrivacyLockShortcutForString:(NSString *)string key:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender;
- (BOOL)handleCandidatePageKey:(NSInteger)keyCode modifiers:(NSUInteger)flags;
- (BOOL)handlePinyinCandidateSelectionKey:(NSInteger)keyCode modifiers:(NSUInteger)flags;
- (BOOL)handlePinyinCandidateSelectionSelector:(SEL)selector;
- (BOOL)shouldUsePinyinCandidateSelection;
- (NSUInteger)candidateIndexForCurrentCommit;
- (void)clampSelectedCandidateIndex;
- (NSUInteger)candidatePanelSelectedIndexForCandidateTexts:(NSArray<NSString *> *)candidateTexts;
- (BOOL)changeCandidatePageByOffset:(NSInteger)offset;
- (void)commitCandidate:(MKCandidate *)candidate client:(id)sender appendText:(NSString *)appendText;
- (void)resetRecentCommittedText;
- (BOOL)isShiftOnlyLetterInputWithModifiers:(NSUInteger)flags;
- (void)appendRawEnglishText:(NSString *)string;
- (BOOL)isSecureTextInputActive;
- (void)startSecureInputMonitor;
- (void)stopSecureInputMonitor;
- (BOOL)shouldMonitorSecureTextInputForActiveApplication;
- (void)pollSecureTextInputState:(NSTimer *)timer;
- (void)bypassForSecureTextInput;
- (BOOL)selectASCIIInputSourceForSecureTextInputIfNeeded;
- (BOOL)showPunctuationCandidatesForString:(NSString *)string client:(id)sender;
- (BOOL)commitPunctuationCandidateIfSelectionKey:(NSString *)string client:(id)sender;
- (BOOL)commitPunctuationCandidateText:(NSString *)displayText client:(id)sender;
- (void)commitCurrentCompositionWithoutAssociationsForClient:(id)sender;
- (void)updatePunctuationCompositionForClient:(id)sender;
- (void)clearPunctuationCandidates;
- (void)setCandidatePool:(NSArray<MKCandidate *> *)candidates resetPage:(BOOL)resetPage;
- (void)updateCurrentCandidatePage;
- (NSArray<MKCandidate *> *)spellingSuggestionCandidatesForCurrentBuffer;
- (NSArray<MKCandidate *> *)spellingSuggestionCandidatesForCurrentBufferWithLimit:(NSUInteger)limit;
- (BOOL)hasSpellingSuggestionCandidates;
- (BOOL)firstCurrentCandidateIsSpellingSuggestion;
- (void)refreshRawEnglishSuggestionsResetPage:(BOOL)resetPage;
- (void)beginCandidateAnchorSessionForClient:(id)sender;
- (void)scheduleCandidatePanelUpdate;
- (void)updateCandidatePanel;
- (id)candidatePanelClientForCurrentState;
- (void)resetCompositionPreservingCandidateAnchor:(BOOL)preserveAnchor;
- (BOOL)shouldShowRawEnglishCandidate;
- (NSString *)rawEnglishCandidateDisplayText;
- (BOOL)isAsciiCodeString:(NSString *)string;

@end

@implementation PurrTypeInputController

- (void)dealloc {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [self stopSecureInputMonitor];
}

- (instancetype)initWithServer:(IMKServer *)server delegate:(id)delegate client:(id)inputClient {
    self = [super initWithServer:server delegate:delegate client:inputClient];
    if (self) {
        _inputState = [[PurrTypeInputState alloc] init];
        _candidatePool = @[];
        _currentCandidates = @[];
        _punctuationCandidateTexts = @[];
        _punctuationAnchorText = @"";
        _selectedCandidateIndex = 0;
        _candidateUpdateSerial = 0;
        _preferences = [PurrTypePreferencesStore sharedStore];
        _enabledInputModes = [_preferences enabledInputModes];
        _engineMode = [_preferences engineMode];
        _privacyLockEnabled = [_preferences privacyLockEnabled];
        _rawEnglishCandidateEnabled = [_preferences rawEnglishCandidateEnabled];
        _spellingSuggestionsEnabled = [_preferences spellingSuggestionsEnabled];
        _spacePagingEnabled = [_preferences spacePagingEnabled];
        _candidatePageSize = [_preferences candidatePageSize];
        _switchInputModeShortcut = [_preferences switchInputModeShortcut];
        _privacyLockShortcut = [_preferences privacyLockShortcut];
        _modeShortcutsByMode = [_preferences modeShortcutsByMode];
        _lastPrivacyLockBacktickTime = 0;
        _pendingLearningReset = [_preferences hasPendingLearningReset];
        _englishSpellChecker = [PurrTypeEnglishSpellChecker sharedChecker];
        _candidatePanel = [[PurrTypeCandidatePanel alloc] init];
        _candidatePanel.delegate = self;
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                            selector:@selector(handlePreferencesChanged:)
                                                                name:MKPreferencesDidChangeNotification
                                                              object:nil
                                                  suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
        [self warmUpEngineInBackground];
    }
    return self;
}

- (void)setValue:(id)value forTag:(NSInteger)tag client:(id)sender {
    (void)tag;

    if (![value isKindOfClass:[NSString class]]) {
        return;
    }

    if (![(NSString *)value isEqualToString:MKInputSourceUnified]) {
        return;
    }
    [super setValue:value forTag:tag client:sender];
}

- (void)warmUpEngineInBackground {
    __weak PurrTypeInputController *weakSelf = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        PurrTypeEngine *engine = [PurrTypeEngine sharedEngine];
        dispatch_async(dispatch_get_main_queue(), ^{
            PurrTypeInputController *strongSelf = weakSelf;
            if (!strongSelf) {
                return;
            }
            if (!strongSelf.engine) {
                strongSelf.engine = engine;
            }
            if (strongSelf.pendingLearningReset) {
                [strongSelf.engine resetLearningState];
                strongSelf.pendingLearningReset = NO;
                [strongSelf.preferences clearPendingLearningReset];
            }
            [strongSelf applyEffectiveLearningState];
            if (strongSelf.inputState.buffer.length > 0) {
                [strongSelf refreshCandidates];
                [strongSelf updateComposition];
            }
        });
    });
}

- (PurrTypeEngine *)engineForInput {
    if (!self.engine) {
        self.engine = [PurrTypeEngine sharedEngine];
        if (self.pendingLearningReset) {
            [self.engine resetLearningState];
            self.pendingLearningReset = NO;
            [self.preferences clearPendingLearningReset];
        }
        [self applyEffectiveLearningState];
    }
    return self.engine;
}

- (id)valueForTag:(NSInteger)tag client:(id)sender {
    (void)tag;
    (void)sender;
    return MKInputSourceUnified;
}

- (NSDictionary *)modes:(id)sender {
    (void)sender;
    return @{};
}

- (BOOL)inputText:(NSString *)string key:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender {
    return [self handleInputText:string
                             key:keyCode
                       modifiers:flags
                          client:sender
                     hasKeyEvent:YES];
}

- (BOOL)inputText:(NSString *)string client:(id)sender {
    return [self handleInputText:string
                             key:MKUnknownKeyCode
                       modifiers:0
                          client:sender
                     hasKeyEvent:NO];
}

- (BOOL)handleInputText:(NSString *)string
                    key:(NSInteger)keyCode
              modifiers:(NSUInteger)flags
                 client:(id)sender
            hasKeyEvent:(BOOL)hasKeyEvent {
    [self rememberActiveInputClient:sender];

    if ([self isSecureTextInputActive]) {
        [self bypassForSecureTextInput];
        return NO;
    }

    if (hasKeyEvent && [self handlePreferencesShortcutForKey:keyCode modifiers:flags client:sender]) {
        return YES;
    }

    if ([self handlePrivacyLockShortcutForString:string key:keyCode modifiers:flags client:sender]) {
        return YES;
    }

    if (hasKeyEvent && [self handleModeShortcutForKey:keyCode modifiers:flags client:sender]) {
        return YES;
    }

    if (hasKeyEvent && (flags & MKHandledModifierMask) != 0) {
        return NO;
    }

    BOOL fallbackReturn = !hasKeyEvent && ([string isEqualToString:@"\n"] || [string isEqualToString:@"\r"]);
    BOOL fallbackTab = !hasKeyEvent && [string isEqualToString:@"\t"];
    BOOL fallbackSpace = !hasKeyEvent && [string isEqualToString:@" "];

    if (self.punctuationCandidateTexts.count > 0) {
        if (hasKeyEvent && (keyCode == MKKeyCodeEscape || keyCode == MKKeyCodeDelete)) {
            [self clearPunctuationCandidates];
            return YES;
        }
        if ((hasKeyEvent && (keyCode == MKKeyCodeReturn ||
                             keyCode == MKKeyCodeKeypadEnter ||
                             keyCode == MKKeyCodeSpace ||
                             keyCode == MKKeyCodeTab)) ||
            fallbackReturn ||
            fallbackTab ||
            fallbackSpace) {
            return [self commitPunctuationCandidateText:self.punctuationCandidateTexts.firstObject client:sender];
        }
        if ([self commitPunctuationCandidateIfSelectionKey:string client:sender]) {
            return YES;
        }
        if ([PurrTypeInputBehavior shouldAutoCommitDefaultPunctuationForInputString:string
                                                                              keyCode:keyCode
                                                                       candidateCount:self.punctuationCandidateTexts.count]) {
            [self commitPunctuationCandidateText:self.punctuationCandidateTexts.firstObject client:sender];
        } else {
            [self clearPunctuationCandidates];
        }
    }

    if (hasKeyEvent && [self handlePinyinCandidateSelectionKey:keyCode modifiers:flags]) {
        return YES;
    }

    if (((hasKeyEvent && keyCode == MKKeyCodeSpace) || fallbackSpace) &&
        [self shouldUsePinyinCandidateSelection]) {
        [self commitCandidateAtIndex:[self candidateIndexForCurrentCommit] client:sender];
        return YES;
    }

    if (hasKeyEvent && [self handleCandidatePageKey:keyCode modifiers:flags]) {
        return YES;
    }

    if (hasKeyEvent && keyCode == MKKeyCodeEscape) {
        return [self cancelCompositionForClient:sender];
    }

    if (hasKeyEvent && keyCode == MKKeyCodeDelete) {
        return [self deleteBackwardForClient:sender];
    }

    if ((hasKeyEvent && (keyCode == MKKeyCodeReturn || keyCode == MKKeyCodeKeypadEnter)) || fallbackReturn) {
        return [self commitRawForClient:sender];
    }

    if ((hasKeyEvent && keyCode == MKKeyCodeTab) || fallbackTab) {
        return self.candidatePool.count > self.candidatePageSize;
    }

    if ((hasKeyEvent && keyCode == MKKeyCodeSpace) || fallbackSpace) {
        return [self commitBestCandidateForClient:sender appendText:@" " appendOnlyWhenRaw:YES];
    }

    if (string.length == 0) {
        return NO;
    }

    if ([self.engineMode isEqualToString:MKInputModeEnglish]) {
        return NO;
    }

    if (self.currentCandidates.count > 0 && [self commitCandidateIfSelectionKey:string client:sender]) {
        return YES;
    }

    if (self.inputState.rawEnglishModeActive &&
        [PurrTypeInputState isRawEnglishContinuationString:string]) {
        [self appendRawEnglishText:string];
        return YES;
    }

    if ([self showPunctuationCandidatesForString:string client:sender]) {
        return YES;
    }

    if ([self isAsciiLetterString:string]) {
        BOOL wasAssociationModeActive = self.inputState.associationModeActive;
        if (wasAssociationModeActive) {
            [self clearAssociations];
        }

        if (self.inputState.buffer.length == 0 || wasAssociationModeActive) {
            [self beginCandidateAnchorSessionForClient:sender];
        }

        BOOL shiftOnlyLetter = [self isShiftOnlyLetterInputWithModifiers:flags];
        if (self.inputState.rawEnglishModeActive || shiftOnlyLetter) {
            [self appendRawEnglishText:string];
            return YES;
        }

        [self.inputState appendCodeText:[string lowercaseString]];
        [self refreshCandidates];

        PurrTypeEngine *engine = [self engineForInput];
        if ([engine prefersRawEnglishForInput:self.inputState.buffer mode:self.engineMode]) {
            self.inputState.rawEnglishModeActive = YES;
            [self refreshRawEnglishSuggestionsResetPage:YES];
            [self updateComposition];
            return YES;
        }

        if ([engine hasCandidatesOrPrefixesForInput:self.inputState.buffer mode:self.engineMode]) {
            [self updateComposition];
            return YES;
        }

        self.inputState.rawEnglishModeActive = YES;
        [self refreshRawEnglishSuggestionsResetPage:YES];
        [self updateComposition];
        return YES;
    }

    if (self.inputState.buffer.length > 0 && [self isCommitSeparator:string]) {
        return [self commitBestCandidateForClient:sender appendText:string appendOnlyWhenRaw:NO];
    }

    return NO;
}

- (BOOL)didCommandBySelector:(SEL)selector client:(id)sender {
    [self rememberActiveInputClient:sender];

    if ([self isSecureTextInputActive]) {
        [self bypassForSecureTextInput];
        return NO;
    }

    if ([self handlePinyinCandidateSelectionSelector:selector]) {
        return YES;
    }

    NSInteger pageOffset = [PurrTypeInputBehavior candidatePageOffsetForSelector:selector
                                                                     candidateCount:self.candidatePool.count
                                                                  candidatePageSize:self.candidatePageSize];
    if (pageOffset != 0) {
        return [self changeCandidatePageByOffset:pageOffset];
    }

    if (selector == @selector(deleteBackward:)) {
        return [self deleteBackwardForClient:sender];
    }

    if (selector == @selector(insertNewline:) || selector == @selector(insertLineBreak:)) {
        return [self commitRawForClient:sender];
    }

    if (selector == @selector(cancelOperation:)) {
        return [self cancelCompositionForClient:sender];
    }

    return NO;
}

- (id)composedString:(id)sender {
    (void)sender;
    return [self.inputState.buffer copy];
}

- (NSAttributedString *)originalString:(id)sender {
    (void)sender;
    return [[NSAttributedString alloc] initWithString:self.inputState.buffer ?: @""];
}

- (NSArray *)candidates:(id)sender {
    (void)sender;
    return [self candidateTexts];
}

- (NSMenu *)menu {
    [self refreshEnabledInputModesFromDefaults];

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"PurrType"];
    [self addDisabledMenuItemWithTitle:[NSString stringWithFormat:@"Current Mode: %@", [self modeDisplayNameForMode:self.engineMode]]
                                toMenu:menu];
    [self addDisabledMenuItemWithTitle:[NSString stringWithFormat:@"Switch Input Mode Shortcut: %@", [PurrTypeInputBehavior displayNameForShortcutSpec:self.switchInputModeShortcut]]
                                toMenu:menu];
    [menu addItem:[NSMenuItem separatorItem]];

    [self addModeMenuItemWithTitle:@"Sucheng" mode:MKInputModeSucheng tag:MKModeMenuTagSucheng shortcutSpec:self.modeShortcutsByMode[MKInputModeSucheng] toMenu:menu];
    [self addModeMenuItemWithTitle:@"New Sucheng" mode:MKInputModeSmartSucheng tag:MKModeMenuTagSmartSucheng shortcutSpec:self.modeShortcutsByMode[MKInputModeSmartSucheng] toMenu:menu];
    [self addModeMenuItemWithTitle:@"Cangjie" mode:MKInputModeCangjie tag:MKModeMenuTagCangjie shortcutSpec:self.modeShortcutsByMode[MKInputModeCangjie] toMenu:menu];
    [self addModeMenuItemWithTitle:@"Pinyin" mode:MKInputModePinyin tag:MKModeMenuTagPinyin shortcutSpec:self.modeShortcutsByMode[MKInputModePinyin] toMenu:menu];
    [menu addItem:[NSMenuItem separatorItem]];

    NSString *candidateKeyTitle = self.rawEnglishCandidateEnabled ?
        [NSString stringWithFormat:@"1-%lu Chinese Candidate, 0 English", (unsigned long)self.candidatePageSize] :
        [NSString stringWithFormat:@"1-%lu Select Chinese Candidate", (unsigned long)self.candidatePageSize];
    [self addDisabledMenuItemWithTitle:candidateKeyTitle toMenu:menu];
    [self addDisabledMenuItemWithTitle:self.spacePagingEnabled ? @"Space / Tab / Right / PageDown: Next Page" : @"Tab / Right / PageDown: Next Page" toMenu:menu];
    [self addDisabledMenuItemWithTitle:@"Left / Shift+Tab / PageUp: Previous Page" toMenu:menu];
    [self addDisabledMenuItemWithTitle:@"Pinyin: Up / Down Select, Space Commit" toMenu:menu];
    [menu addItem:[NSMenuItem separatorItem]];

    [self addDisabledMenuItemWithTitle:[self learningStatusTitle] toMenu:menu];
    NSMenuItem *learningEnabledItem = [[NSMenuItem alloc] initWithTitle:@"Enable New Sucheng Learning"
                                                                 action:@selector(toggleLearning:)
                                                          keyEquivalent:@""];
    learningEnabledItem.target = self;
    learningEnabledItem.state = [self.preferences learningEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:learningEnabledItem];

    NSMenuItem *privacyLockItem = [[NSMenuItem alloc] initWithTitle:@"Privacy Lock"
                                                             action:@selector(togglePrivacyLock:)
                                                      keyEquivalent:[PurrTypeInputBehavior keyEquivalentForShortcutSpec:self.privacyLockShortcut]];
    privacyLockItem.target = self;
    privacyLockItem.keyEquivalentModifierMask = [PurrTypeInputBehavior keyEquivalentModifierMaskForShortcutSpec:self.privacyLockShortcut];
    privacyLockItem.state = self.privacyLockEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:privacyLockItem];

    [self addDisabledMenuItemWithTitle:[NSString stringWithFormat:@"Privacy Lock Shortcut: %@", [PurrTypeInputBehavior displayNameForShortcutSpec:self.privacyLockShortcut]]
                                toMenu:menu];

    NSMenuItem *resetLearningItem = [[NSMenuItem alloc] initWithTitle:@"Reset New Sucheng Learning"
                                                               action:@selector(resetLearning:)
                                                        keyEquivalent:@""];
    resetLearningItem.target = self;
    [menu addItem:resetLearningItem];

    [self addDisabledMenuItemWithTitle:@"Sucheng: Quick Classic Fixed Positions" toMenu:menu];
    [self addDisabledMenuItemWithTitle:@"New Sucheng: Hashed Local Ranking" toMenu:menu];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *preferencesItem = [[NSMenuItem alloc] initWithTitle:@"PurrType Preferences..."
                                                             action:@selector(showPreferences:)
                                                      keyEquivalent:@","];
    preferencesItem.target = self;
    preferencesItem.keyEquivalentModifierMask = NSEventModifierFlagControl | NSEventModifierFlagShift;
    [menu addItem:preferencesItem];
    return menu;
}

- (void)selectCangjieMode:(id)sender {
    (void)sender;
    [self switchToEngineMode:MKInputModeCangjie];
}

- (void)selectSuchengMode:(id)sender {
    (void)sender;
    [self switchToEngineMode:MKInputModeSucheng];
}

- (void)selectSmartSuchengMode:(id)sender {
    (void)sender;
    [self switchToEngineMode:MKInputModeSmartSucheng];
}

- (void)selectPinyinMode:(id)sender {
    (void)sender;
    [self switchToEngineMode:MKInputModePinyin];
}

- (void)candidateSelected:(NSAttributedString *)candidateString {
    id target = [self activeInputClient];
    if (self.punctuationCandidateTexts.count > 0) {
        [self commitPunctuationCandidateText:candidateString.string ?: @"" client:target];
        return;
    }

    if ([candidateString.string isEqualToString:[self rawEnglishCandidateDisplayText]]) {
        [self commitRawForClient:target];
        return;
    }

    NSUInteger index = [self indexForDisplayedCandidateText:candidateString.string ?: @""];
    if (index == NSNotFound || index >= self.currentCandidates.count) {
        return;
    }
    [self commitCandidateAtIndex:index client:target];
}

- (void)candidatePanel:(PurrTypeCandidatePanel *)panel didSelectCandidateText:(NSString *)candidateText {
    (void)panel;
    [self candidateSelected:[[NSAttributedString alloc] initWithString:candidateText ?: @""]];
}

- (void)commitComposition:(id)sender {
    if (self.punctuationCandidateTexts.count > 0) {
        [self commitPunctuationCandidateText:self.punctuationCandidateTexts.firstObject client:sender];
        return;
    }

    if (self.inputState.buffer.length == 0) {
        return;
    }
    [self commitText:[self.inputState.buffer copy] client:sender resetFirst:NO showAssociations:NO];
}

- (void)activateServer:(id)sender {
    [super activateServer:sender];
    [self rememberActiveInputClient:sender];
    [self startSecureInputMonitor];
}

- (void)deactivateServer:(id)sender {
    [self rememberActiveInputClient:sender];
    [self stopSecureInputMonitor];
    [self commitComposition:sender];
    [self resetComposition];
    self.lastPrivacyLockBacktickTime = 0;
    self.lastInputClient = nil;
    [super deactivateServer:sender];
}

- (void)hidePalettes {
    self.candidateUpdateSerial += 1;
    [self.candidatePanel hide];
    [self.candidatePanel clearAnchorSession];
    [self clearPunctuationCandidates];
}

- (NSUInteger)recognizedEvents:(id)sender {
    (void)sender;
    return NSEventMaskKeyDown;
}

- (BOOL)deleteBackwardForClient:(id)sender {
    (void)sender;
    if (self.punctuationCandidateTexts.count > 0) {
        [self clearPunctuationCandidates];
        return YES;
    }

    if (self.inputState.associationModeActive) {
        [self clearAssociations];
        return YES;
    }

    if (self.inputState.buffer.length == 0) {
        return NO;
    }

    [self.inputState deleteBackward];
    if (self.inputState.buffer.length == 0) {
        [self resetComposition];
        [self updateComposition];
        return YES;
    }

    [self refreshCandidates];
    [self updateComposition];
    return YES;
}

- (BOOL)cancelCompositionForClient:(id)sender {
    (void)sender;
    if (self.punctuationCandidateTexts.count > 0) {
        [self clearPunctuationCandidates];
        return YES;
    }

    if (self.inputState.associationModeActive) {
        [self clearAssociations];
        return YES;
    }

    if (self.inputState.buffer.length == 0) {
        return NO;
    }

    [self resetComposition];
    [self updateComposition];
    return YES;
}

- (BOOL)commitRawForClient:(id)sender {
    if (self.inputState.buffer.length == 0) {
        return NO;
    }

    [self commitText:[self.inputState.buffer copy] client:sender resetFirst:NO showAssociations:NO];
    return YES;
}

- (BOOL)commitBestCandidateForClient:(id)sender appendText:(NSString *)appendText appendOnlyWhenRaw:(BOOL)appendOnlyWhenRaw {
    if (self.inputState.buffer.length == 0) {
        if (self.inputState.associationModeActive && self.currentCandidates.count > 0) {
            [self commitCandidateAtIndex:0 client:sender];
            return YES;
        }
        return NO;
    }

    if (self.inputState.rawEnglishModeActive) {
        NSString *text = [self.inputState.buffer copy];
        if (appendText.length > 0) {
            text = [text stringByAppendingString:appendText];
        }
        [self commitText:text client:sender resetFirst:YES showAssociations:NO];
        return YES;
    }

    BOOL usingCandidate = self.currentCandidates.count > 0;
    if (usingCandidate) {
        if ([self firstCurrentCandidateIsSpellingSuggestion]) {
            NSString *text = [self.inputState.buffer copy];
            if (appendText.length > 0) {
                text = [text stringByAppendingString:appendText];
            }
            [self commitText:text client:sender resetFirst:YES showAssociations:NO];
            return YES;
        }
        NSUInteger candidateIndex = [self candidateIndexForCurrentCommit];
        NSString *candidateAppendText = appendOnlyWhenRaw ? @"" : appendText;
        [self commitCandidate:self.currentCandidates[candidateIndex] client:sender appendText:candidateAppendText];
        return YES;
    }

    NSString *text = [self.inputState.buffer copy];
    if (appendText.length > 0) {
        text = [text stringByAppendingString:appendText];
    }

    [self commitText:text client:sender resetFirst:YES showAssociations:usingCandidate];
    return YES;
}

- (BOOL)commitCandidateIfSelectionKey:(NSString *)string client:(id)sender {
    if (string.length != 1 || self.currentCandidates.count == 0) {
        return NO;
    }

    unichar character = [string characterAtIndex:0];
    if (character == '0' && [self shouldShowRawEnglishCandidate]) {
        return [self commitRawForClient:sender];
    }

    if (character < '1' || character > '9') {
        return NO;
    }

    NSUInteger index = (NSUInteger)(character - '1');
    if (index >= self.currentCandidates.count) {
        return NO;
    }

    [self commitCandidateAtIndex:index client:sender];
    return YES;
}

- (void)refreshCandidates {
    if (self.inputState.rawEnglishModeActive) {
        self.inputState.associationModeActive = NO;
        [self refreshRawEnglishSuggestionsResetPage:YES];
        return;
    }

    self.inputState.associationModeActive = NO;
    PurrTypeEngine *engine = [self engineForInput];
    NSArray<MKCandidate *> *primaryCandidates =
        [engine candidatesForInput:self.inputState.buffer limit:MKCandidateFetchLimit mode:self.engineMode];
    NSArray<MKCandidate *> *spellingCandidates =
        [self spellingSuggestionCandidatesForCurrentBufferWithLimit:
            [PurrTypeInputBehavior spellingSuggestionLimitForCandidatePageSize:self.candidatePageSize]];
    NSArray<MKCandidate *> *candidatePool =
        [PurrTypeInputBehavior candidatePoolByMergingPrimaryCandidates:primaryCandidates
                                                   spellingCandidates:spellingCandidates
                                                             pageSize:self.candidatePageSize];
    [self setCandidatePool:candidatePool resetPage:YES];
}

- (BOOL)isSupportedEngineMode:(NSString *)mode {
    return [self.preferences isSupportedEngineMode:mode];
}

- (BOOL)isEnabledEngineMode:(NSString *)mode {
    return [self isSupportedEngineMode:mode] &&
           [PurrTypeInputBehavior inputMode:mode isEnabledInModes:self.enabledInputModes];
}

- (void)refreshEnabledInputModesFromDefaults {
    [self.preferences synchronize];

    NSArray<NSString *> *nextEnabledInputModes = [self.preferences enabledInputModes];
    if (![self.enabledInputModes isEqualToArray:nextEnabledInputModes]) {
        _enabledInputModes = [nextEnabledInputModes copy];
    }

    NSString *nextMode = [self.preferences engineMode];

    if (![self.engineMode isEqualToString:nextMode]) {
        self.engineMode = nextMode;
        [self resetRecentCommittedText];
        [self resetComposition];
        [self updateComposition];
    }
}

- (void)setEnabledInputModes:(NSArray<NSString *> *)enabledInputModes {
    NSArray<NSString *> *normalizedModes = [PurrTypeInputBehavior normalizedEnabledInputModes:enabledInputModes];
    _enabledInputModes = [normalizedModes copy];
    [self.preferences setEnabledInputModes:normalizedModes];

    if (![self isEnabledEngineMode:self.engineMode]) {
        NSString *fallbackMode = [self.preferences engineMode];
        self.engineMode = fallbackMode;
        [self resetRecentCommittedText];
        [self resetComposition];
        [self updateComposition];
    }
}

- (void)switchToEngineMode:(NSString *)mode {
    [self switchToEngineMode:mode updateClientInputMode:YES client:[self activeInputClient]];
}

- (void)switchToEngineMode:(NSString *)mode updateClientInputMode:(BOOL)updateClientInputMode client:(id)sender {
    (void)updateClientInputMode;
    (void)sender;

    [self refreshEnabledInputModesFromDefaults];

    if (![self isEnabledEngineMode:mode] || [self.engineMode isEqualToString:mode]) {
        return;
    }

    self.engineMode = mode;
    [self.preferences setEngineMode:mode];
    [self resetRecentCommittedText];
    [self resetComposition];
    [self updateComposition];
}

- (void)addModeMenuItemWithTitle:(NSString *)title
                            mode:(NSString *)mode
                             tag:(NSInteger)tag
                     shortcutSpec:(NSString *)shortcutSpec
                          toMenu:(NSMenu *)menu {
    if (![self isEnabledEngineMode:mode]) {
        return;
    }

    SEL action = @selector(selectCangjieMode:);
    if ([mode isEqualToString:MKInputModeSucheng]) {
        action = @selector(selectSuchengMode:);
    } else if ([mode isEqualToString:MKInputModeSmartSucheng]) {
        action = @selector(selectSmartSuchengMode:);
    } else if ([mode isEqualToString:MKInputModePinyin]) {
        action = @selector(selectPinyinMode:);
    }

    NSString *keyEquivalent = [PurrTypeInputBehavior keyEquivalentForShortcutSpec:shortcutSpec];
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:keyEquivalent ?: @""];
    item.keyEquivalentModifierMask = [PurrTypeInputBehavior keyEquivalentModifierMaskForShortcutSpec:shortcutSpec];
    item.target = self;
    item.tag = tag;
    item.enabled = YES;
    item.state = [self.engineMode isEqualToString:mode] ? NSControlStateValueOn : NSControlStateValueOff;
    item.image = [self modeMenuImageForMode:mode];
    [menu addItem:item];
}

- (void)addDisabledMenuItemWithTitle:(NSString *)title toMenu:(NSMenu *)menu {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title ?: @"" action:nil keyEquivalent:@""];
    item.enabled = NO;
    [menu addItem:item];
}

- (NSImage *)modeMenuImageForMode:(NSString *)mode {
    BOOL isKnownMode = [mode isEqualToString:MKInputModeSucheng] ||
                       [mode isEqualToString:MKInputModeSmartSucheng] ||
                       [mode isEqualToString:MKInputModeCangjie] ||
                       [mode isEqualToString:MKInputModePinyin];
    if (!isKnownMode) {
        return nil;
    }

    NSImage *image = [[NSImage imageNamed:@"PurrType"] copy];
    if (!image) {
        NSURL *icnsURL = [[NSBundle mainBundle] URLForResource:@"PurrType" withExtension:@"icns"];
        image = icnsURL ? [[NSImage alloc] initWithContentsOfURL:icnsURL] : nil;
    }
    if (!image) {
        return nil;
    }
    image.size = NSMakeSize(16.0, 16.0);
    return image;
}

- (NSString *)modeDisplayNameForMode:(NSString *)mode {
    if ([mode isEqualToString:MKInputModeSucheng]) {
        return @"Sucheng";
    }
    if ([mode isEqualToString:MKInputModeSmartSucheng]) {
        return @"New Sucheng";
    }
    if ([mode isEqualToString:MKInputModeCangjie]) {
        return @"Cangjie";
    }
    if ([mode isEqualToString:MKInputModePinyin]) {
        return @"Pinyin";
    }
    return @"Sucheng";
}

- (NSString *)learningStatusTitle {
    if (self.privacyLockEnabled) {
        return @"New Sucheng Learning: Paused by Privacy Lock";
    }

    if (![self effectiveLearningEnabledFromPreferences]) {
        return @"New Sucheng Learning: Disabled";
    }

    return @"New Sucheng Learning: Enabled · Local Ranking";
}

- (BOOL)privacyLockPausesLearningContextForMode:(NSString *)mode {
    return [PurrTypeInputBehavior privacyLockShouldPauseLearningContextForMode:mode
                                                                       enabled:self.privacyLockEnabled];
}

- (void)resetLearning:(id)sender {
    (void)sender;
    [self.preferences requestLearningReset];
    [self resetLearningStateForPreferenceRequest];
}

- (void)resetLearningStateForPreferenceRequest {
    self.pendingLearningReset = YES;
    if (self.engine) {
        [self.engine resetLearningState];
        self.pendingLearningReset = NO;
        [self.preferences clearPendingLearningReset];
    } else {
        [PurrTypeEngine resetPersistedLearningStateAtDefaultPath];
    }
    [self resetRecentCommittedText];
    [self resetComposition];
    [self updateComposition];
}

- (void)toggleLearning:(id)sender {
    (void)sender;
    [self setLearningEnabled:![self.preferences learningEnabled]];
}

- (void)togglePrivacyLock:(id)sender {
    (void)sender;
    [self setPrivacyLockEnabled:!self.privacyLockEnabled];
}

- (void)setLearningEnabled:(BOOL)enabled {
    [self.preferences setLearningEnabled:enabled];
    [self applyEffectiveLearningState];
    [self resetRecentCommittedText];
    [self resetComposition];
    [self updateComposition];
}

- (void)setPrivacyLockEnabled:(BOOL)enabled {
    _privacyLockEnabled = enabled;
    [self.preferences setPrivacyLockEnabled:enabled];
    [self applyEffectiveLearningState];
    [self resetRecentCommittedText];
    [self resetComposition];
    [self updateComposition];
}

- (BOOL)effectiveLearningEnabledFromPreferences {
    return !self.privacyLockEnabled && [self.preferences learningEnabled];
}

- (void)applyEffectiveLearningState {
    if (self.engine) {
        self.engine.learningEnabled = [self effectiveLearningEnabledFromPreferences];
    }
}

- (void)setRawEnglishCandidateEnabled:(BOOL)enabled {
    _rawEnglishCandidateEnabled = enabled;
    [self.preferences setRawEnglishCandidateEnabled:enabled];
    [self setCandidatePool:self.candidatePool resetPage:NO];
    [self updateComposition];
}

- (void)setSpellingSuggestionsEnabled:(BOOL)enabled {
    _spellingSuggestionsEnabled = enabled;
    [self.preferences setSpellingSuggestionsEnabled:enabled];
    if (self.inputState.buffer.length > 0) {
        if (self.inputState.rawEnglishModeActive) {
            [self refreshRawEnglishSuggestionsResetPage:YES];
        } else {
            [self refreshCandidates];
        }
    }
    [self updateComposition];
}

- (void)setSpacePagingEnabled:(BOOL)enabled {
    _spacePagingEnabled = enabled;
    [self.preferences setSpacePagingEnabled:enabled];
}

- (void)setCandidatePageSize:(NSUInteger)pageSize {
    if (pageSize != 5 && pageSize != 9) {
        pageSize = [PurrTypeInputBehavior candidatePageSize];
    }

    _candidatePageSize = pageSize;
    [self.preferences setCandidatePageSize:pageSize];
    [self setCandidatePool:self.candidatePool resetPage:NO];
    [self updateComposition];
}

- (void)setSwitchInputModeShortcut:(NSString *)shortcutSpec {
    _switchInputModeShortcut = [[PurrTypeInputBehavior normalizedSwitchInputModeShortcutSpec:shortcutSpec] copy];
    [self.preferences setSwitchInputModeShortcut:self.switchInputModeShortcut];
}

- (void)setPrivacyLockShortcut:(NSString *)shortcutSpec {
    _privacyLockShortcut = [[PurrTypeInputBehavior normalizedPrivacyLockShortcutSpec:shortcutSpec] copy];
    self.lastPrivacyLockBacktickTime = 0;
    [self.preferences setPrivacyLockShortcut:self.privacyLockShortcut];
}

- (void)setModeShortcut:(NSString *)shortcutSpec forMode:(NSString *)mode {
    if (![self isSupportedEngineMode:mode]) {
        return;
    }

    NSString *normalizedShortcut = [PurrTypeInputBehavior normalizedModeShortcutSpec:shortcutSpec forMode:mode];
    if (![self.preferences setModeShortcut:normalizedShortcut forMode:mode]) {
        return;
    }
    self.modeShortcutsByMode = [self.preferences modeShortcutsByMode];
}

- (void)showPreferences:(id)sender {
    (void)sender;
    [self launchPreferencesHelper];
}

- (void)launchPreferencesHelper {
    NSURL *helperURL = [[[NSBundle mainBundle] resourceURL] URLByAppendingPathComponent:@"PurrTypePreferences.app"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:helperURL.path]) {
        NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
        configuration.activates = YES;
        [[NSWorkspace sharedWorkspace] openApplicationAtURL:helperURL
                                              configuration:configuration
                                          completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
            (void)app;
            if (error) {
                NSLog(@"PurrType preferences helper launch failed: %@", error.localizedDescription);
            }
        }];
        return;
    }

    NSLog(@"PurrType preferences helper missing at %@", helperURL.path);
    [[PurrTypePreferencesWindowController sharedController] showWithEngine:self.engine delegate:self];
}

- (id)activeInputClient {
    return self.lastInputClient ?: [self client];
}

- (void)rememberActiveInputClient:(id)sender {
    self.lastInputClient = sender ?: [self client];
}

- (void)handlePreferencesChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL shouldResetLearning = [notification.userInfo[MKPreferencesResetLearningKey] boolValue] ||
                                   [self.preferences hasPendingLearningReset];
        NSArray<NSString *> *nextEnabledInputModes = [self.preferences enabledInputModes];
        if (![self.enabledInputModes isEqualToArray:nextEnabledInputModes]) {
            _enabledInputModes = [nextEnabledInputModes copy];
        }

        NSString *nextMode = [self.preferences engineMode];
        if (![self.engineMode isEqualToString:nextMode]) {
            [self switchToEngineMode:nextMode];
        }

        BOOL nextPrivacyLockEnabled = [self.preferences privacyLockEnabled];
        BOOL nextLearningEnabled = !nextPrivacyLockEnabled && [self.preferences learningEnabled];
        if (self.privacyLockEnabled != nextPrivacyLockEnabled ||
            (self.engine && self.engine.learningEnabled != nextLearningEnabled)) {
            _privacyLockEnabled = nextPrivacyLockEnabled;
            [self applyEffectiveLearningState];
            [self resetRecentCommittedText];
            [self resetComposition];
            [self updateComposition];
        }

        BOOL nextRawEnglishCandidateEnabled = [self.preferences rawEnglishCandidateEnabled];
        if (self.rawEnglishCandidateEnabled != nextRawEnglishCandidateEnabled) {
            _rawEnglishCandidateEnabled = nextRawEnglishCandidateEnabled;
            [self setCandidatePool:self.candidatePool resetPage:NO];
            [self updateComposition];
        }

        BOOL nextSpellingSuggestionsEnabled = [self.preferences spellingSuggestionsEnabled];
        if (self.spellingSuggestionsEnabled != nextSpellingSuggestionsEnabled) {
            _spellingSuggestionsEnabled = nextSpellingSuggestionsEnabled;
            if (self.inputState.buffer.length > 0) {
                if (self.inputState.rawEnglishModeActive) {
                    [self refreshRawEnglishSuggestionsResetPage:YES];
                } else {
                    [self refreshCandidates];
                }
            }
            [self updateComposition];
        }

        _spacePagingEnabled = [self.preferences spacePagingEnabled];
        NSUInteger nextCandidatePageSize = [self.preferences candidatePageSize];
        if (self.candidatePageSize != nextCandidatePageSize) {
            _candidatePageSize = nextCandidatePageSize;
            [self setCandidatePool:self.candidatePool resetPage:NO];
            [self updateComposition];
        }

        NSString *nextSwitchInputModeShortcut = [self.preferences switchInputModeShortcut];
        if (![self.switchInputModeShortcut isEqualToString:nextSwitchInputModeShortcut]) {
            _switchInputModeShortcut = [nextSwitchInputModeShortcut copy];
        }

        NSString *nextPrivacyLockShortcut = [self.preferences privacyLockShortcut];
        if (![self.privacyLockShortcut isEqualToString:nextPrivacyLockShortcut]) {
            _privacyLockShortcut = [nextPrivacyLockShortcut copy];
            self.lastPrivacyLockBacktickTime = 0;
        }
        _modeShortcutsByMode = [[self.preferences modeShortcutsByMode] copy];

        if (shouldResetLearning) {
            [self resetLearningStateForPreferenceRequest];
        }
    });
}

- (NSString *)preferencesCurrentMode {
    return self.engineMode;
}

- (void)preferencesSwitchToMode:(NSString *)mode {
    if (![self isSupportedEngineMode:mode]) {
        return;
    }
    [self switchToEngineMode:mode];
}

- (BOOL)preferencesLearningEnabled {
    return [self.preferences learningEnabled];
}

- (void)preferencesSetLearningEnabled:(BOOL)enabled {
    [self setLearningEnabled:enabled];
}

- (BOOL)preferencesPrivacyLockEnabled {
    return self.privacyLockEnabled;
}

- (void)preferencesSetPrivacyLockEnabled:(BOOL)enabled {
    [self setPrivacyLockEnabled:enabled];
}

- (BOOL)preferencesRawEnglishCandidateEnabled {
    return self.rawEnglishCandidateEnabled;
}

- (void)preferencesSetRawEnglishCandidateEnabled:(BOOL)enabled {
    [self setRawEnglishCandidateEnabled:enabled];
}

- (BOOL)preferencesSpellingSuggestionsEnabled {
    return self.spellingSuggestionsEnabled;
}

- (void)preferencesSetSpellingSuggestionsEnabled:(BOOL)enabled {
    [self setSpellingSuggestionsEnabled:enabled];
}

- (BOOL)preferencesSpacePagingEnabled {
    return self.spacePagingEnabled;
}

- (void)preferencesSetSpacePagingEnabled:(BOOL)enabled {
    [self setSpacePagingEnabled:enabled];
}

- (NSUInteger)preferencesCandidatePageSize {
    return self.candidatePageSize;
}

- (void)preferencesSetCandidatePageSize:(NSUInteger)pageSize {
    [self setCandidatePageSize:pageSize];
}

- (NSArray<NSString *> *)preferencesEnabledInputModes {
    return self.enabledInputModes ?: [PurrTypeInputBehavior defaultEnabledInputModes];
}

- (void)preferencesSetEnabledInputModes:(NSArray<NSString *> *)enabledInputModes {
    [self setEnabledInputModes:enabledInputModes];
}

- (NSString *)preferencesSwitchInputModeShortcut {
    return self.switchInputModeShortcut;
}

- (void)preferencesSetSwitchInputModeShortcut:(NSString *)shortcutSpec {
    [self setSwitchInputModeShortcut:shortcutSpec];
}

- (NSString *)preferencesPrivacyLockShortcut {
    return self.privacyLockShortcut;
}

- (void)preferencesSetPrivacyLockShortcut:(NSString *)shortcutSpec {
    [self setPrivacyLockShortcut:shortcutSpec];
}

- (NSDictionary<NSString *, NSString *> *)preferencesModeShortcutsByMode {
    return self.modeShortcutsByMode;
}

- (void)preferencesSetModeShortcut:(NSString *)shortcutSpec forMode:(NSString *)mode {
    [self setModeShortcut:shortcutSpec forMode:mode];
}

- (void)preferencesResetLearning {
    [self resetLearning:nil];
}

- (BOOL)handleModeShortcutForKey:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender {
    (void)sender;
    [self refreshEnabledInputModesFromDefaults];

    NSString *switchShortcut = self.switchInputModeShortcut ?: [PurrTypeInputBehavior defaultSwitchInputModeShortcutSpec];
    if ([PurrTypeInputBehavior shortcutSpec:switchShortcut matchesKeyCode:keyCode modifiers:flags]) {
        [self switchToNextEngineMode];
        return YES;
    }

    NSString *mode = [PurrTypeInputBehavior modeForShortcutKeyCode:keyCode
                                                         modifiers:flags
                                                   shortcutsByMode:self.modeShortcutsByMode ?: @{}
                                                       enabledModes:self.enabledInputModes];
    if (!mode) {
        NSString *disabledMode = [PurrTypeInputBehavior modeForShortcutKeyCode:keyCode
                                                                      modifiers:flags
                                                                shortcutsByMode:self.modeShortcutsByMode ?: @{}
                                                                   enabledModes:[PurrTypeInputBehavior orderedInputModes]];
        if (disabledMode && ![self isEnabledEngineMode:disabledMode]) {
            NSBeep();
            return YES;
        }
        return NO;
    }

    if (![self isEnabledEngineMode:mode]) {
        NSBeep();
        return YES;
    }

    [self switchToEngineMode:mode];
    return YES;
}

- (void)switchToNextEngineMode {
    [self refreshEnabledInputModesFromDefaults];

    NSArray<NSString *> *modes = [PurrTypeInputBehavior normalizedEnabledInputModes:self.enabledInputModes];
    if (modes.count == 0) {
        return;
    }
    NSUInteger currentIndex = [modes indexOfObject:self.engineMode ?: MKInputModeSucheng];
    NSUInteger nextIndex = currentIndex == NSNotFound ? 0 : (currentIndex + 1) % modes.count;
    [self switchToEngineMode:modes[nextIndex]];
}

- (BOOL)handlePreferencesShortcutForKey:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender {
    (void)sender;
    if (![PurrTypeInputBehavior isPreferencesShortcutKeyCode:keyCode modifiers:flags]) {
        return NO;
    }

    [self launchPreferencesHelper];
    return YES;
}

- (BOOL)handlePrivacyLockShortcutForString:(NSString *)string key:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender {
    (void)sender;
    NSString *shortcut = self.privacyLockShortcut ?: [PurrTypeInputBehavior defaultPrivacyLockShortcutSpec];
    if ([PurrTypeInputBehavior shortcutSpec:shortcut matchesKeyCode:keyCode modifiers:flags]) {
        self.lastPrivacyLockBacktickTime = 0;
        [self setPrivacyLockEnabled:!self.privacyLockEnabled];
        return YES;
    }

    if (![PurrTypeInputBehavior isDoubleBacktickShortcutSpec:shortcut]) {
        self.lastPrivacyLockBacktickTime = 0;
        return NO;
    }

    if (![PurrTypeInputBehavior isBacktickKeyCode:keyCode inputString:string modifiers:flags]) {
        self.lastPrivacyLockBacktickTime = 0;
        return NO;
    }

    BOOL idleOrBacktickPunctuation =
        (self.inputState.buffer.length == 0 &&
         !self.inputState.rawEnglishModeActive &&
         !self.inputState.associationModeActive) ||
        (self.punctuationCandidateTexts.count > 0 && [self.punctuationAnchorText isEqualToString:@"`"]);
    if (!idleOrBacktickPunctuation) {
        self.lastPrivacyLockBacktickTime = 0;
        return NO;
    }

    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    if (self.lastPrivacyLockBacktickTime > 0 &&
        now - self.lastPrivacyLockBacktickTime <= MKPrivacyLockDoubleBacktickInterval) {
        self.lastPrivacyLockBacktickTime = 0;
        [self clearPunctuationCandidates];
        [self setPrivacyLockEnabled:!self.privacyLockEnabled];
        return YES;
    }

    self.lastPrivacyLockBacktickTime = now;
    return NO;
}

- (BOOL)handleCandidatePageKey:(NSInteger)keyCode modifiers:(NSUInteger)flags {
    if ([self hasSpellingSuggestionCandidates]) {
        return NO;
    }

    NSInteger offset = [PurrTypeInputBehavior candidatePageOffsetForKeyCode:keyCode
                                                                     modifiers:flags
                                                                candidateCount:self.candidatePool.count
                                                            spacePagingEnabled:self.spacePagingEnabled
                                                             candidatePageSize:self.candidatePageSize];
    return offset != 0 && [self changeCandidatePageByOffset:offset];
}

- (BOOL)handlePinyinCandidateSelectionKey:(NSInteger)keyCode modifiers:(NSUInteger)flags {
    if (![self shouldUsePinyinCandidateSelection]) {
        return NO;
    }

    NSInteger offset = [PurrTypeInputBehavior candidateSelectionOffsetForKeyCode:keyCode
                                                                      modifiers:flags
                                                                 candidateCount:self.currentCandidates.count];
    if (offset == 0) {
        return NO;
    }

    NSUInteger nextIndex = [PurrTypeInputBehavior candidateSelectionIndexFromIndex:self.selectedCandidateIndex
                                                                            offset:offset
                                                                    candidateCount:self.currentCandidates.count];
    if (nextIndex != self.selectedCandidateIndex) {
        self.selectedCandidateIndex = nextIndex;
        [self updateCandidatePanel];
    }
    return YES;
}

- (BOOL)handlePinyinCandidateSelectionSelector:(SEL)selector {
    if (![self shouldUsePinyinCandidateSelection]) {
        return NO;
    }

    NSInteger offset = [PurrTypeInputBehavior candidateSelectionOffsetForSelector:selector
                                                                  candidateCount:self.currentCandidates.count];
    if (offset == 0) {
        return NO;
    }

    NSUInteger nextIndex = [PurrTypeInputBehavior candidateSelectionIndexFromIndex:self.selectedCandidateIndex
                                                                            offset:offset
                                                                    candidateCount:self.currentCandidates.count];
    if (nextIndex != self.selectedCandidateIndex) {
        self.selectedCandidateIndex = nextIndex;
        [self updateCandidatePanel];
    }
    return YES;
}

- (BOOL)shouldUsePinyinCandidateSelection {
    return [self.engineMode isEqualToString:MKInputModePinyin] &&
           self.inputState.buffer.length > 0 &&
           !self.inputState.rawEnglishModeActive &&
           !self.inputState.associationModeActive &&
           self.punctuationCandidateTexts.count == 0 &&
           self.currentCandidates.count > 0 &&
           ![self hasSpellingSuggestionCandidates];
}

- (NSUInteger)candidateIndexForCurrentCommit {
    if (![self shouldUsePinyinCandidateSelection]) {
        return 0;
    }
    return self.selectedCandidateIndex < self.currentCandidates.count ? self.selectedCandidateIndex : 0;
}

- (void)clampSelectedCandidateIndex {
    if (self.currentCandidates.count == 0) {
        self.selectedCandidateIndex = 0;
        return;
    }
    if (self.selectedCandidateIndex >= self.currentCandidates.count) {
        self.selectedCandidateIndex = self.currentCandidates.count - 1;
    }
}

- (NSUInteger)candidatePanelSelectedIndexForCandidateTexts:(NSArray<NSString *> *)candidateTexts {
    if (![self shouldUsePinyinCandidateSelection]) {
        return 0;
    }

    NSUInteger displayIndex = [self candidateIndexForCurrentCommit];
    if ([self shouldShowRawEnglishCandidate]) {
        displayIndex += 1;
    }
    return displayIndex < candidateTexts.count ? displayIndex : 0;
}

- (BOOL)changeCandidatePageByOffset:(NSInteger)offset {
    NSUInteger pageSize = self.candidatePageSize;
    if (self.candidatePool.count <= pageSize) {
        return NO;
    }

    NSUInteger pageCount = (self.candidatePool.count + pageSize - 1) / pageSize;
    NSInteger nextPage = (NSInteger)self.candidatePageIndex + offset;
    if (nextPage < 0) {
        nextPage = (NSInteger)pageCount - 1;
    } else if ((NSUInteger)nextPage >= pageCount) {
        nextPage = 0;
    }

    self.candidatePageIndex = (NSUInteger)nextPage;
    self.selectedCandidateIndex = 0;
    [self updateCurrentCandidatePage];
    [self updateCandidatePanel];
    return YES;
}

- (void)setCandidatePool:(NSArray<MKCandidate *> *)candidates resetPage:(BOOL)resetPage {
    self.candidatePool = candidates ?: @[];
    if (resetPage) {
        self.candidatePageIndex = 0;
        self.selectedCandidateIndex = 0;
    }
    [self updateCurrentCandidatePage];
}

- (void)updateCurrentCandidatePage {
    NSUInteger pageIndex = self.candidatePageIndex;
    self.currentCandidates = [PurrTypeInputBehavior candidatePageFromPool:self.candidatePool
                                                                   pageIndex:&pageIndex
                                                                    pageSize:self.candidatePageSize];
    self.candidatePageIndex = pageIndex;
    [self clampSelectedCandidateIndex];
}

- (NSArray<MKCandidate *> *)spellingSuggestionCandidatesForCurrentBuffer {
    return [self spellingSuggestionCandidatesForCurrentBufferWithLimit:self.candidatePageSize];
}

- (NSArray<MKCandidate *> *)spellingSuggestionCandidatesForCurrentBufferWithLimit:(NSUInteger)limit {
    if (!self.spellingSuggestionsEnabled || limit == 0) {
        return @[];
    }

    NSArray<NSString *> *suggestions = [self.englishSpellChecker suggestionsForToken:self.inputState.buffer ?: @""
                                                                               limit:limit];
    NSMutableArray<MKCandidate *> *candidates = [NSMutableArray arrayWithCapacity:suggestions.count];
    for (NSString *suggestion in suggestions) {
        [candidates addObject:[[MKCandidate alloc] initWithText:suggestion
                                                           code:self.inputState.buffer ?: @""
                                                         source:MKSpellingCandidateSource
                                                         weight:100]];
    }
    return candidates;
}

- (BOOL)hasSpellingSuggestionCandidates {
    if (self.currentCandidates.count == 0) {
        return NO;
    }
    for (MKCandidate *candidate in self.currentCandidates) {
        if (![candidate.source isEqualToString:MKSpellingCandidateSource]) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)firstCurrentCandidateIsSpellingSuggestion {
    MKCandidate *candidate = self.currentCandidates.firstObject;
    return [candidate.source isEqualToString:MKSpellingCandidateSource];
}

- (void)refreshRawEnglishSuggestionsResetPage:(BOOL)resetPage {
    [self setCandidatePool:[self spellingSuggestionCandidatesForCurrentBuffer] resetPage:resetPage];
}

- (NSArray<NSString *> *)candidateTexts {
    if (self.punctuationCandidateTexts.count > 0) {
        return self.punctuationCandidateTexts;
    }

    if ([self hasSpellingSuggestionCandidates]) {
        return [PurrTypeInputBehavior displayTextsForCandidates:self.currentCandidates
                                                        buffer:self.inputState.buffer ?: @""
                                          rawEnglishModeActive:NO
                                         associationModeActive:NO
                                   rawEnglishCandidateEnabled:YES];
    }

    return [PurrTypeInputBehavior displayTextsForCandidates:self.currentCandidates
                                                        buffer:self.inputState.buffer ?: @""
                                          rawEnglishModeActive:self.inputState.rawEnglishModeActive
                                         associationModeActive:self.inputState.associationModeActive
                                   rawEnglishCandidateEnabled:self.rawEnglishCandidateEnabled];
}

- (void)commitText:(NSString *)text client:(id)sender resetFirst:(BOOL)resetFirst {
    [self commitText:text client:sender resetFirst:resetFirst showAssociations:NO];
}

- (void)commitText:(NSString *)text client:(id)sender resetFirst:(BOOL)resetFirst showAssociations:(BOOL)showAssociations {
    id target = sender ?: [self activeInputClient];
    BOOL effectiveShowAssociations = showAssociations && ![self privacyLockPausesLearningContextForMode:self.engineMode];
    if (resetFirst) {
        [self resetCompositionPreservingCandidateAnchor:effectiveShowAssociations];
    }

    if ([target respondsToSelector:@selector(insertText:replacementRange:)]) {
        [target insertText:text replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    }

    if (!resetFirst) {
        [self resetCompositionPreservingCandidateAnchor:effectiveShowAssociations];
    }

    if (effectiveShowAssociations) {
        [self showAssociationsForCommittedText:text];
    }

    if (!effectiveShowAssociations) {
        [self resetRecentCommittedText];
    }
    self.lastCommittedCandidateText = nil;
}

- (void)resetComposition {
    [self resetCompositionPreservingCandidateAnchor:NO];
}

- (void)resetCompositionPreservingCandidateAnchor:(BOOL)preserveAnchor {
    [self.inputState resetComposition];
    self.candidatePool = @[];
    self.currentCandidates = @[];
    self.punctuationCandidateTexts = @[];
    self.punctuationAnchorText = @"";
    self.candidatePageIndex = 0;
    self.selectedCandidateIndex = 0;
    self.candidateUpdateSerial += 1;
    [self.candidatePanel hide];
    if (!preserveAnchor) {
        [self.candidatePanel clearAnchorSession];
    }
}

- (void)clearAssociations {
    [self.inputState clearAssociations];
    self.candidatePool = @[];
    self.currentCandidates = @[];
    self.punctuationCandidateTexts = @[];
    self.punctuationAnchorText = @"";
    self.candidatePageIndex = 0;
    self.selectedCandidateIndex = 0;
    self.candidateUpdateSerial += 1;
    [self.candidatePanel hide];
    [self.candidatePanel clearAnchorSession];
}

- (void)updateComposition {
    id target = [self activeInputClient];
    if (![target respondsToSelector:@selector(setMarkedText:selectionRange:replacementRange:)]) {
        return;
    }

    NSString *markedText = self.inputState.buffer ?: @"";
    [target setMarkedText:markedText
           selectionRange:NSMakeRange(markedText.length, 0)
         replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    [self scheduleCandidatePanelUpdate];
}

- (void)commitCandidateAtIndex:(NSUInteger)index client:(id)sender {
    if (index >= self.currentCandidates.count) {
        return;
    }

    [self commitCandidate:self.currentCandidates[index] client:sender appendText:@""];
}

- (void)commitCandidate:(MKCandidate *)candidate client:(id)sender appendText:(NSString *)appendText {
    if ([candidate.source isEqualToString:MKSpellingCandidateSource]) {
        NSString *text = candidate.text ?: @"";
        if (appendText.length > 0) {
            text = [text stringByAppendingString:appendText];
        }
        [self commitText:text client:sender resetFirst:YES showAssociations:NO];
        self.lastCommittedCandidateText = nil;
        [self resetRecentCommittedText];
        return;
    }

    PurrTypeEngine *engine = [self engineForInput];
    [engine recordSelectionForCandidate:candidate previousText:self.lastCommittedCandidateText mode:self.engineMode];
    [engine recordCommittedCandidateText:candidate.text code:candidate.code mode:self.engineMode];

    NSString *text = candidate.text;
    BOOL shouldShowAssociations = appendText.length == 0 && ![self privacyLockPausesLearningContextForMode:self.engineMode];
    if (appendText.length > 0) {
        text = [text stringByAppendingString:appendText];
    }

    [self commitText:text client:sender resetFirst:YES showAssociations:shouldShowAssociations];
    self.lastCommittedCandidateText = shouldShowAssociations ? candidate.text : nil;
    if (!shouldShowAssociations) {
        [self resetRecentCommittedText];
    }
}

- (void)resetRecentCommittedText {
    [self.engine resetLearningContext];
}

- (BOOL)isShiftOnlyLetterInputWithModifiers:(NSUInteger)flags {
    return [PurrTypeInputBehavior isShiftOnlyLetterInputWithModifiers:flags];
}

- (void)appendRawEnglishText:(NSString *)string {
    [self.inputState appendRawEnglishText:string ?: @""];
    [self refreshRawEnglishSuggestionsResetPage:YES];
    [self updateComposition];
}

- (BOOL)isSecureTextInputActive {
    return IsSecureEventInputEnabled();
}

- (void)startSecureInputMonitor {
    if (![self shouldMonitorSecureTextInputForActiveApplication]) {
        return;
    }

    if (self.secureInputMonitorTimer) {
        [self pollSecureTextInputState:self.secureInputMonitorTimer];
        return;
    }

    NSTimer *timer = [NSTimer timerWithTimeInterval:MKSecureInputMonitorInterval
                                             target:self
                                           selector:@selector(pollSecureTextInputState:)
                                           userInfo:nil
                                            repeats:YES];
    timer.tolerance = MKSecureInputMonitorInterval / 2.0;
    self.secureInputMonitorTimer = timer;
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    [self pollSecureTextInputState:timer];
}

- (void)stopSecureInputMonitor {
    [self.secureInputMonitorTimer invalidate];
    self.secureInputMonitorTimer = nil;
}

- (BOOL)shouldMonitorSecureTextInputForActiveApplication {
    return MKFrontmostApplicationMayOwnSecureTextInputPrompt();
}

- (void)pollSecureTextInputState:(NSTimer *)timer {
    (void)timer;
    if (![self shouldMonitorSecureTextInputForActiveApplication]) {
        [self stopSecureInputMonitor];
        return;
    }

    if (![self isSecureTextInputActive]) {
        return;
    }

    [self bypassForSecureTextInput];
}

- (void)bypassForSecureTextInput {
    [self.inputState resetComposition];
    self.candidatePool = @[];
    self.currentCandidates = @[];
    self.punctuationCandidateTexts = @[];
    self.punctuationAnchorText = @"";
    self.candidatePageIndex = 0;
    self.selectedCandidateIndex = 0;
    self.candidateUpdateSerial += 1;
    [self resetRecentCommittedText];
    [self.candidatePanel hide];
    [self.candidatePanel clearAnchorSession];
    if ([self selectASCIIInputSourceForSecureTextInputIfNeeded]) {
        [self stopSecureInputMonitor];
    }
}

- (BOOL)selectASCIIInputSourceForSecureTextInputIfNeeded {
    TISInputSourceRef currentSource = TISCopyCurrentKeyboardInputSource();
    if (MKInputSourceIsSelectableASCIIKeyboardSource(currentSource)) {
        CFRelease(currentSource);
        return YES;
    }
    if (currentSource) {
        CFRelease(currentSource);
    }

    TISInputSourceRef asciiSource = MKCopySecureTextASCIIInputSource();
    if (!asciiSource) {
        return NO;
    }

    OSStatus status = TISSelectInputSource(asciiSource);
    CFRelease(asciiSource);
    return status == noErr;
}

- (BOOL)showPunctuationCandidatesForString:(NSString *)string client:(id)sender {
    NSArray<NSString *> *displayTexts = [PurrTypeInputBehavior punctuationCandidateDisplayTextsForString:string ?: @""];
    if (displayTexts.count == 0) {
        return NO;
    }

    id target = sender ?: [self activeInputClient];
    if (self.inputState.buffer.length > 0) {
        [self commitCurrentCompositionWithoutAssociationsForClient:target];
    } else if (self.inputState.associationModeActive) {
        [self clearAssociations];
    }

    self.punctuationCandidateTexts = displayTexts;
    self.punctuationAnchorText = [string copy] ?: @"";
    [self beginCandidateAnchorSessionForClient:target];
    [self updatePunctuationCompositionForClient:target];
    return YES;
}

- (BOOL)commitPunctuationCandidateIfSelectionKey:(NSString *)string client:(id)sender {
    if (string.length != 1 || self.punctuationCandidateTexts.count == 0) {
        return NO;
    }

    unichar character = [string characterAtIndex:0];
    if (character < '1' || character > '9') {
        return NO;
    }

    NSUInteger index = (NSUInteger)(character - '1');
    if (index >= self.punctuationCandidateTexts.count) {
        return NO;
    }

    return [self commitPunctuationCandidateText:self.punctuationCandidateTexts[index] client:sender];
}

- (BOOL)commitPunctuationCandidateText:(NSString *)displayText client:(id)sender {
    NSString *punctuation = [PurrTypeInputBehavior punctuationTextForDisplayText:displayText ?: @""];
    if (punctuation.length == 0) {
        return NO;
    }

    [self clearPunctuationCandidates];
    [self commitText:punctuation client:sender resetFirst:NO showAssociations:NO];
    return YES;
}

- (void)commitCurrentCompositionWithoutAssociationsForClient:(id)sender {
    if (self.inputState.buffer.length == 0) {
        return;
    }

    if (self.currentCandidates.count > 0) {
        NSUInteger candidateIndex = [self candidateIndexForCurrentCommit];
        MKCandidate *candidate = self.currentCandidates[candidateIndex];
        if ([candidate.source isEqualToString:MKSpellingCandidateSource]) {
            [self commitText:[self.inputState.buffer copy] client:sender resetFirst:YES showAssociations:NO];
            self.lastCommittedCandidateText = nil;
            [self resetRecentCommittedText];
            return;
        }

        PurrTypeEngine *engine = [self engineForInput];
        [engine recordSelectionForCandidate:candidate previousText:self.lastCommittedCandidateText mode:self.engineMode];
        [engine recordCommittedCandidateText:candidate.text code:candidate.code mode:self.engineMode];
        [self commitText:candidate.text client:sender resetFirst:YES showAssociations:NO];
        self.lastCommittedCandidateText = nil;
        [self resetRecentCommittedText];
        return;
    }

    [self commitText:[self.inputState.buffer copy] client:sender resetFirst:YES showAssociations:NO];
}

- (void)updatePunctuationCompositionForClient:(id)sender {
    id target = sender ?: [self activeInputClient];
    NSString *markedText = self.punctuationAnchorText ?: @"";
    if ([target respondsToSelector:@selector(setMarkedText:selectionRange:replacementRange:)]) {
        [target setMarkedText:markedText
               selectionRange:NSMakeRange(markedText.length, 0)
             replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    }
    [self scheduleCandidatePanelUpdate];
}

- (void)clearPunctuationCandidates {
    BOOL hadMarkedPunctuation = self.punctuationAnchorText.length > 0;
    self.punctuationCandidateTexts = @[];
    self.punctuationAnchorText = @"";
    self.candidateUpdateSerial += 1;
    if (hadMarkedPunctuation) {
        id target = [self activeInputClient];
        if ([target respondsToSelector:@selector(setMarkedText:selectionRange:replacementRange:)]) {
            [target setMarkedText:@""
                   selectionRange:NSMakeRange(0, 0)
                 replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
        }
    }
    [self.candidatePanel hide];
    [self.candidatePanel clearAnchorSession];
}

- (void)showAssociationsForCommittedText:(NSString *)text {
    if ([self privacyLockPausesLearningContextForMode:self.engineMode]) {
        return;
    }

    PurrTypeEngine *engine = [self engineForInput];
    NSArray<MKCandidate *> *associations = [engine associatedCandidatesForText:text
                                                                         limit:MKAssociationCandidateFetchLimit
                                                                          mode:self.engineMode];
    if (associations.count == 0) {
        return;
    }

    self.inputState.associationModeActive = YES;
    [self setCandidatePool:associations resetPage:YES];
    [self scheduleCandidatePanelUpdate];
}

- (void)beginCandidateAnchorSessionForClient:(id)sender {
    id target = sender ?: [self activeInputClient];
    [self.candidatePanel beginAnchorSessionForClient:target];
}

- (void)scheduleCandidatePanelUpdate {
    self.candidateUpdateSerial += 1;
    NSUInteger serial = self.candidateUpdateSerial;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (serial == self.candidateUpdateSerial) {
            [self updateCandidatePanel];
        }
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.035 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (serial == self.candidateUpdateSerial) {
            [self updateCandidatePanel];
        }
    });
}

- (void)updateCandidatePanel {
    NSArray *candidateTexts = [self candidateTexts];
    if (candidateTexts.count > 0) {
        BOOL usePreservedAnchor = [self shouldUsePreservedCandidatePanelAnchorForCurrentState];
        NSUInteger pageCount = 0;
        if (self.punctuationCandidateTexts.count == 0 && self.candidatePool.count > self.candidatePageSize) {
            pageCount = (self.candidatePool.count + self.candidatePageSize - 1) / self.candidatePageSize;
        }
        [self.candidatePanel showCandidates:candidateTexts
                                  nearClient:[self candidatePanelClientForCurrentState]
                        anchorCharacterIndex:[self candidatePanelAnchorCharacterIndex]
                                   pageIndex:self.candidatePageIndex
                                   pageCount:pageCount
                         usePreservedAnchor:usePreservedAnchor
                              selectedIndex:[self candidatePanelSelectedIndexForCandidateTexts:candidateTexts]];
    } else {
        [self.candidatePanel hide];
    }
}

- (id)candidatePanelClientForCurrentState {
    if ([self shouldUsePreservedCandidatePanelAnchorForCurrentState]) {
        return nil;
    }

    return [self activeInputClient];
}

- (BOOL)shouldUsePreservedCandidatePanelAnchorForCurrentState {
    if (self.inputState.associationModeActive &&
        self.inputState.buffer.length == 0 &&
        self.punctuationCandidateTexts.count == 0) {
        return YES;
    }

    return NO;
}

- (NSNumber *)candidatePanelAnchorCharacterIndex {
    if (self.punctuationCandidateTexts.count > 0 && self.punctuationAnchorText.length > 0) {
        return @(self.punctuationAnchorText.length - 1);
    }

    NSString *buffer = self.inputState.buffer ?: @"";
    if (buffer.length == 0) {
        return nil;
    }
    return @(buffer.length - 1);
}

- (NSString *)displayTextForCandidate:(MKCandidate *)candidate index:(NSUInteger)index {
    return [PurrTypeInputBehavior displayTextForCandidate:candidate index:index];
}

- (BOOL)shouldShowRawEnglishCandidate {
    if ([self hasSpellingSuggestionCandidates]) {
        return [PurrTypeInputBehavior shouldShowRawEnglishCandidateForBuffer:self.inputState.buffer ?: @""
                                                        rawEnglishModeActive:NO
                                                        associationModeActive:NO
                                                   rawEnglishCandidateEnabled:YES
                                                               candidateCount:self.currentCandidates.count];
    }
    return [PurrTypeInputBehavior shouldShowRawEnglishCandidateForBuffer:self.inputState.buffer ?: @""
                                                       rawEnglishModeActive:self.inputState.rawEnglishModeActive
                                                      associationModeActive:self.inputState.associationModeActive
                                                rawEnglishCandidateEnabled:self.rawEnglishCandidateEnabled
                                                              candidateCount:self.currentCandidates.count];
}

- (NSString *)rawEnglishCandidateDisplayText {
    return [self shouldShowRawEnglishCandidate] ? [PurrTypeInputBehavior rawEnglishCandidateDisplayTextForBuffer:self.inputState.buffer ?: @""] : @"";
}

- (NSUInteger)indexForDisplayedCandidateText:(NSString *)displayedText {
    for (NSUInteger index = 0; index < self.currentCandidates.count; index += 1) {
        MKCandidate *candidate = self.currentCandidates[index];
        if ([displayedText isEqualToString:candidate.text] ||
            [displayedText isEqualToString:[self displayTextForCandidate:candidate index:index]]) {
            return index;
        }
    }
    return NSNotFound;
}

- (BOOL)isAsciiLetterString:(NSString *)string {
    if (string.length != 1) {
        return NO;
    }

    unichar character = [string characterAtIndex:0];
    return (character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z');
}

- (BOOL)isCommitSeparator:(NSString *)string {
    if (string.length != 1) {
        return NO;
    }

    unichar character = [string characterAtIndex:0];
    return [[NSCharacterSet punctuationCharacterSet] characterIsMember:character] ||
           [[NSCharacterSet symbolCharacterSet] characterIsMember:character];
}

- (BOOL)isAsciiCodeString:(NSString *)string {
    return [PurrTypeInputBehavior isAsciiCodeString:string ?: @""];
}

@end
