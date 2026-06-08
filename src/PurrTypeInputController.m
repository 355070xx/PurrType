#import "PurrTypeInputController.h"
#import "PurrTypeEngine.h"
#import "PurrTypeInputBehavior.h"
#import "PurrTypeInputState.h"
#import "PurrTypeEnglishSpellChecker.h"
#import "PurrTypeQuickPhraseStore.h"
#import "PurrTypeCandidatePanel.h"
#import "PurrTypeVoiceFloatingButton.h"
#import "PurrTypePreferencesWindowController.h"
#import "PurrTypePreferencesConstants.h"
#import "PurrTypePreferencesStore.h"
#import "PurrTypeSpeechInputController.h"
#import "PurrTypeVoiceHomophoneStore.h"
#import <Carbon/Carbon.h>
#include <math.h>

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
static NSString *const MKQuickPhraseCandidateSource = @"quickPhrase";
static NSString *const MKVoiceInputStatusReady = @"Voice Input: Ready";
static NSUInteger const MKVoiceLiveCandidateLimit = 5;
static NSUInteger const MKVoiceLiveCandidateMaximumChangedLength = 12;
static NSUInteger const MKVoiceHomophoneFallbackScanLimit = 16;

static NSString *MKFrontmostApplicationBundleIdentifier(void) {
    return [NSWorkspace sharedWorkspace].frontmostApplication.bundleIdentifier ?: @"";
}

static BOOL MKFrontmostApplicationMayOwnSecureTextInputPrompt(void) {
    NSString *bundleIdentifier = MKFrontmostApplicationBundleIdentifier();
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

@interface PurrTypeInputController () <PurrTypeCandidatePanelDelegate, PurrTypePreferencesWindowControllerDelegate, PurrTypeVoiceFloatingButtonDelegate>

@property(nonatomic, strong) PurrTypeInputState *inputState;
@property(nonatomic, strong) NSArray<MKCandidate *> *candidatePool;
@property(nonatomic, strong) NSArray<MKCandidate *> *currentCandidates;
@property(nonatomic, copy) NSArray<NSString *> *punctuationCandidateTexts;
@property(nonatomic, copy) NSString *punctuationAnchorText;
@property(nonatomic, strong) PurrTypeCandidatePanel *candidatePanel;
@property(nonatomic, strong) PurrTypeVoiceFloatingButton *voiceFloatingButton;
@property(nonatomic, strong) PurrTypeEngine *engine;
@property(nonatomic, strong) PurrTypePreferencesStore *preferences;
@property(nonatomic, strong) PurrTypeQuickPhraseStore *quickPhraseStore;
@property(nonatomic, copy) NSString *engineMode;
@property(nonatomic, copy) NSString *lastCommittedCandidateText;
@property(nonatomic, copy) NSString *lastTextContextFallbackText;
@property(nonatomic, weak) id lastTextContextFallbackClient;
@property(nonatomic, assign) NSUInteger candidatePageIndex;
@property(nonatomic, assign) NSUInteger selectedCandidateIndex;
@property(nonatomic, assign) NSUInteger candidateUpdateSerial;
@property(nonatomic, assign) BOOL rawEnglishCandidateEnabled;
@property(nonatomic, copy) NSString *rawEnglishCandidatePosition;
@property(nonatomic, assign) BOOL spellingSuggestionsEnabled;
@property(nonatomic, assign) BOOL spacePagingEnabled;
@property(nonatomic, assign) BOOL decimalPointShortcutEnabled;
@property(nonatomic, assign) BOOL chineseContextPunctuationEnabled;
@property(nonatomic, assign) BOOL privacyLockEnabled;
@property(nonatomic, assign) BOOL associationCandidatesEnabled;
@property(nonatomic, assign) BOOL associationContinuationEnabled;
@property(nonatomic, assign) BOOL clearReadingOnCompositionFailureEnabled;
@property(nonatomic, assign) NSUInteger candidatePageSize;
@property(nonatomic, copy) NSArray<NSString *> *enabledInputModes;
@property(nonatomic, copy) NSString *switchInputModeShortcut;
@property(nonatomic, copy) NSString *privacyLockShortcut;
@property(nonatomic, copy) NSString *voiceRecognitionLocaleIdentifier;
@property(nonatomic, copy) NSDictionary<NSString *, NSString *> *modeShortcutsByMode;
@property(nonatomic, assign) BOOL voiceFloatingButtonVisible;
@property(nonatomic, assign) BOOL inputServerActive;
@property(nonatomic, assign) NSTimeInterval lastPrivacyLockBacktickTime;
@property(nonatomic, weak) id lastInputClient;
@property(nonatomic, assign) BOOL pendingLearningReset;
@property(nonatomic, strong) NSTimer *secureInputMonitorTimer;
@property(nonatomic, strong) PurrTypeEnglishSpellChecker *englishSpellChecker;
@property(nonatomic, strong) PurrTypeSpeechInputController *speechInputController;
@property(nonatomic, strong) PurrTypeVoiceHomophoneStore *voiceHomophoneStore;
@property(nonatomic, copy) NSString *voiceInputSessionIdentifier;
@property(nonatomic, copy) NSString *voiceInputStatusTitle;
@property(nonatomic, copy) NSString *voiceInputLatestTranscript;
@property(nonatomic, copy) NSString *voiceInputLatestRecognitionTranscript;
@property(nonatomic, copy) NSString *voiceInputConfirmedRecognitionPrefix;
@property(nonatomic, copy) NSArray<NSString *> *voiceInputLatestAlternativeTranscripts;
@property(nonatomic, assign) BOOL voiceInputMarkedTextActive;
@property(nonatomic, assign) BOOL voiceInputFinalTranscriptCommitted;
@property(nonatomic, assign) BOOL voiceLiveCandidateVisible;
@property(nonatomic, copy) NSArray<NSString *> *voiceLiveCandidateTexts;
@property(nonatomic, copy) NSDictionary<NSString *, NSString *> *voiceLiveCandidateReplacementTextsByCandidateText;
@property(nonatomic, assign) NSUInteger voiceCandidateUpdateSerial;

- (void)warmUpEngineInBackground;
- (PurrTypeEngine *)engineForInput;
- (BOOL)effectiveLearningEnabledFromPreferences;
- (BOOL)isSupportedEngineMode:(NSString *)mode;
- (BOOL)isEnabledEngineMode:(NSString *)mode;
- (void)refreshEnabledInputModesFromDefaults;
- (BOOL)applyEffectiveInputModeSettings;
- (void)applyCandidatePanelPreferences;
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
- (void)startCantoneseVoiceInput:(id)sender;
- (void)stopVoiceInput:(id)sender;
- (void)confirmVoiceTranscript:(id)sender;
- (void)stopVoiceInputForReason:(NSString *)reason;
- (void)commitCurrentVoiceTranscriptForReason:(NSString *)reason replacementText:(NSString *)replacementText client:(id)sender;
- (NSArray<NSString *> *)voiceInputContextualStrings;
- (NSArray<NSString *> *)voiceInputUserContextualStrings;
- (NSString *)voiceInputContextualPhraseFromString:(NSString *)text;
- (BOOL)isCurrentVoiceInputSessionIdentifier:(NSString *)sessionIdentifier;
- (NSArray<NSString *> *)voiceLiveCandidateTextsForAlternatives:(NSArray<NSString *> *)alternativeTranscripts visibleTranscript:(NSString *)visibleTranscript;
- (NSArray<NSString *> *)voiceHomophoneCandidateTextsForVisibleTranscript:(NSString *)visibleTranscript;
- (void)scheduleVoiceLiveCandidates:(NSArray<NSString *> *)candidateTexts nearClient:(id)sender;
- (NSNumber *)voiceCandidatePanelAnchorCharacterIndex;
- (void)showVoiceLiveCandidates:(NSArray<NSString *> *)candidateTexts nearClient:(id)sender;
- (void)hideVoiceLiveCandidates;
- (NSString *)visibleVoiceTranscriptForRecognitionTranscript:(NSString *)recognitionTranscript;
- (NSString *)visibleVoiceTranscriptForRecognitionTranscript:(NSString *)recognitionTranscript confirmedPrefix:(NSString *)confirmedPrefix;
- (NSString *)stableVoiceVisibleTranscriptForTranscript:(NSString *)visibleTranscript;
- (BOOL)shouldCommitLatestVoiceInputTranscriptWhenStoppingForReason:(NSString *)reason;
- (BOOL)hasActiveNonVoiceComposition;
- (BOOL)isVoiceInputActiveOrPending;
- (NSString *)voiceInputStatusTitleForMenu;
- (void)handleVoiceInputTranscript:(NSString *)transcript isFinal:(BOOL)isFinal;
- (void)handleVoiceInputTranscript:(NSString *)transcript alternativeTranscripts:(NSArray<NSString *> *)alternativeTranscripts isFinal:(BOOL)isFinal;
- (void)handleVoiceInputTranscript:(NSString *)transcript
             alternativeTranscripts:(NSArray<NSString *> *)alternativeTranscripts
                            isFinal:(BOOL)isFinal
                  sessionIdentifier:(NSString *)sessionIdentifier;
- (void)applyVoicePartialTranscript:(NSString *)transcript;
- (void)commitVoiceFinalTranscript:(NSString *)transcript;
- (void)syncVoiceFloatingButtonState;
- (void)clearVoiceInputMarkedTextForClient:(id)sender;
- (void)handleVoiceInputError:(NSError *)error;
- (void)handleVoiceInputError:(NSError *)error sessionIdentifier:(NSString *)sessionIdentifier;
- (void)showPreferences:(id)sender;
- (void)setLearningEnabled:(BOOL)enabled;
- (void)setPrivacyLockEnabled:(BOOL)enabled;
- (void)applyEffectiveLearningState;
- (void)resetLearningStateForPreferenceRequest;
- (void)setRawEnglishCandidateEnabled:(BOOL)enabled;
- (void)setRawEnglishCandidatePosition:(NSString *)position;
- (void)setSpellingSuggestionsEnabled:(BOOL)enabled;
- (void)setSpacePagingEnabled:(BOOL)enabled;
- (void)setDecimalPointShortcutEnabled:(BOOL)enabled;
- (void)setChineseContextPunctuationEnabled:(BOOL)enabled;
- (void)setCandidatePageSize:(NSUInteger)pageSize;
- (void)setCandidatePanelOrientation:(NSString *)orientation;
- (void)setCandidatePanelFontSize:(CGFloat)fontSize;
- (void)setCandidatePanelHighlightColor:(NSString *)highlightColor;
- (void)setAssociationCandidatesEnabled:(BOOL)enabled;
- (void)setAssociationContinuationEnabled:(BOOL)enabled;
- (void)setClearReadingOnCompositionFailureEnabled:(BOOL)enabled forMode:(NSString *)mode;
- (void)setSwitchInputModeShortcut:(NSString *)shortcutSpec;
- (void)setPrivacyLockShortcut:(NSString *)shortcutSpec;
- (void)setVoiceRecognitionLocaleIdentifier:(NSString *)localeIdentifier;
- (void)setVoiceFloatingButtonVisible:(BOOL)visible;
- (void)setModeShortcut:(NSString *)shortcutSpec forMode:(NSString *)mode;
- (void)handlePreferencesChanged:(NSNotification *)notification;
- (void)launchPreferencesHelper;
- (id)activeInputClient;
- (void)rememberActiveInputClient:(id)sender;
- (void)clearTransientInputStateAfterClientChange;
- (NSString *)activeApplicationBundleIdentifier;
- (BOOL)handleInputText:(NSString *)string
                    key:(NSInteger)keyCode
              modifiers:(NSUInteger)flags
                 client:(id)sender
            hasKeyEvent:(BOOL)hasKeyEvent;
- (BOOL)shouldBypassFinderNonTextInputForString:(NSString *)string client:(id)sender;
- (BOOL)hasActiveMarkedCompositionForFinderBypass;
- (void)clearTransientInputStateForFinderBypass;
- (BOOL)hasTextInsertionContextForClient:(id)sender;
- (BOOL)hasTextAroundSelectedRange:(NSRange)selectedRange client:(id)sender;
- (BOOL)hasUsableTextCaretRectForSelectedRange:(NSRange)selectedRange client:(id)sender;
- (BOOL)isUsableTextCaretRect:(NSRect)rect selectedRange:(NSRange)selectedRange;
- (BOOL)handlePreferencesShortcutForKey:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender;
- (BOOL)handleModeShortcutForKey:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender;
- (BOOL)handleVoiceInputShortcutForKey:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender;
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
- (void)rememberTextContextFallback:(NSString *)text client:(id)sender;
- (void)recordPassthroughTextContextForString:(NSString *)string client:(id)sender;
- (NSString *)textContextFallbackForClient:(id)sender;
- (void)clearTextContextFallback;
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
- (NSString *)punctuationContextTextForClient:(id)sender;
- (NSString *)textBeforeInsertionPointForClient:(id)sender maximumLength:(NSUInteger)maximumLength;
- (BOOL)insertLiteralPunctuationText:(NSString *)text client:(id)sender;
- (BOOL)commitPunctuationCandidateIfSelectionKey:(NSString *)string client:(id)sender;
- (BOOL)commitPunctuationCandidateText:(NSString *)displayText client:(id)sender;
- (BOOL)convertSemicolonPunctuationToQuickPhraseWithString:(NSString *)string client:(id)sender;
- (void)commitCurrentCompositionWithoutAssociationsForClient:(id)sender;
- (void)updatePunctuationCompositionForClient:(id)sender;
- (void)clearPunctuationCandidates;
- (void)setCandidatePool:(NSArray<MKCandidate *> *)candidates resetPage:(BOOL)resetPage;
- (void)updateCurrentCandidatePage;
- (NSArray<MKCandidate *> *)spellingSuggestionCandidatesForCurrentBuffer;
- (NSArray<MKCandidate *> *)spellingSuggestionCandidatesForCurrentBufferWithLimit:(NSUInteger)limit;
- (NSArray<MKCandidate *> *)quickPhraseCandidatesForCurrentBuffer;
- (BOOL)hasSpellingSuggestionCandidates;
- (BOOL)firstCurrentCandidateIsQuickPhrase;
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
    [self.speechInputController stop];
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
        _quickPhraseStore = [PurrTypeQuickPhraseStore defaultStore];
        _enabledInputModes = [_preferences enabledInputModes];
        _engineMode = [_preferences engineMode];
        _privacyLockEnabled = [_preferences privacyLockEnabled];
        _rawEnglishCandidateEnabled = [_preferences rawEnglishCandidateEnabled];
        _rawEnglishCandidatePosition = [_preferences rawEnglishCandidatePosition];
        _spellingSuggestionsEnabled = [_preferences spellingSuggestionsEnabled];
        _spacePagingEnabled = [_preferences effectiveSpacePagingEnabledForMode:_engineMode];
        _decimalPointShortcutEnabled = [_preferences decimalPointShortcutEnabled];
        _chineseContextPunctuationEnabled = [_preferences chineseContextPunctuationEnabled];
        _candidatePageSize = [_preferences effectiveCandidatePageSizeForMode:_engineMode];
        _associationCandidatesEnabled = [_preferences associationCandidatesEnabled];
        _associationContinuationEnabled = [_preferences associationContinuationEnabled];
        _clearReadingOnCompositionFailureEnabled = [_preferences clearReadingOnCompositionFailureEnabledForMode:_engineMode];
        _switchInputModeShortcut = [_preferences switchInputModeShortcut];
        _privacyLockShortcut = [_preferences privacyLockShortcut];
        _voiceRecognitionLocaleIdentifier = [_preferences voiceRecognitionLocaleIdentifier];
        _modeShortcutsByMode = [_preferences modeShortcutsByMode];
        _voiceFloatingButtonVisible = [_preferences voiceFloatingButtonVisible];
        _lastPrivacyLockBacktickTime = 0;
        _pendingLearningReset = [_preferences hasPendingLearningReset];
        _englishSpellChecker = [PurrTypeEnglishSpellChecker sharedChecker];
        _speechInputController = [[PurrTypeSpeechInputController alloc] init];
        _voiceHomophoneStore = [PurrTypeVoiceHomophoneStore storeWithBundle:[NSBundle mainBundle]];
        _voiceHomophoneStore.learningEnabled = !_privacyLockEnabled && [_preferences learningEnabled];
        _voiceInputStatusTitle = MKVoiceInputStatusReady;
        _voiceInputLatestAlternativeTranscripts = @[];
        _voiceLiveCandidateTexts = @[];
        _voiceLiveCandidateReplacementTextsByCandidateText = @{};
        _candidatePanel = [[PurrTypeCandidatePanel alloc] init];
        _candidatePanel.delegate = self;
        _voiceFloatingButton = [PurrTypeVoiceFloatingButton sharedButton];
        [self applyCandidatePanelPreferences];
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

    if (hasKeyEvent && [self handleVoiceInputShortcutForKey:keyCode modifiers:flags client:sender]) {
        return YES;
    }

    if ([self isVoiceInputActiveOrPending] || self.voiceInputMarkedTextActive) {
        [self stopVoiceInputForReason:@"Keyboard Input"];
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
        if ([self convertSemicolonPunctuationToQuickPhraseWithString:string client:sender]) {
            return YES;
        }
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
        [self clearTextContextFallback];
        return NO;
    }

    if ([self.engineMode isEqualToString:MKInputModeEnglish]) {
        [self recordPassthroughTextContextForString:string client:sender];
        return NO;
    }

    if ([self shouldBypassFinderNonTextInputForString:string client:sender]) {
        [self clearTransientInputStateForFinderBypass];
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
        BOOL hasCandidatesOrPrefixes = [engine hasCandidatesOrPrefixesForInput:self.inputState.buffer mode:self.engineMode];
        if ([engine prefersRawEnglishForInput:self.inputState.buffer mode:self.engineMode]) {
            self.inputState.rawEnglishModeActive = YES;
            [self refreshRawEnglishSuggestionsResetPage:YES];
            [self updateComposition];
            return YES;
        }

        if (hasCandidatesOrPrefixes) {
            [self updateComposition];
            return YES;
        }

        BOOL shouldKeepFailedCompositionAsEnglish =
            self.candidatePool.count > 0 ||
            [engine looksLikeRawEnglishInput:self.inputState.buffer mode:self.engineMode];
        if (self.clearReadingOnCompositionFailureEnabled && !shouldKeepFailedCompositionAsEnglish) {
            [self resetComposition];
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

    [self recordPassthroughTextContextForString:string client:sender];
    return NO;
}

- (BOOL)didCommandBySelector:(SEL)selector client:(id)sender {
    [self rememberActiveInputClient:sender];

    if ([self isSecureTextInputActive]) {
        [self bypassForSecureTextInput];
        return NO;
    }

    if ([self isVoiceInputActiveOrPending] || self.voiceInputMarkedTextActive) {
        [self stopVoiceInputForReason:@"Keyboard Command"];
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

    BOOL voiceInputActiveOrPending = [self isVoiceInputActiveOrPending];
    NSString *voiceInputShortcut = [PurrTypeInputBehavior defaultVoiceInputShortcutSpec];
    NSString *voiceInputShortcutKey = [PurrTypeInputBehavior keyEquivalentForShortcutSpec:voiceInputShortcut];
    NSUInteger voiceInputShortcutModifiers = [PurrTypeInputBehavior keyEquivalentModifierMaskForShortcutSpec:voiceInputShortcut];
    NSMenuItem *startVoiceItem = [[NSMenuItem alloc] initWithTitle:@"Start Voice Input"
                                                            action:@selector(startCantoneseVoiceInput:)
                                                     keyEquivalent:voiceInputActiveOrPending ? @"" : voiceInputShortcutKey];
    startVoiceItem.target = self;
    startVoiceItem.keyEquivalentModifierMask = voiceInputActiveOrPending ? 0 : voiceInputShortcutModifiers;
    startVoiceItem.enabled = !voiceInputActiveOrPending;
    [menu addItem:startVoiceItem];

    NSMenuItem *stopVoiceItem = [[NSMenuItem alloc] initWithTitle:@"Stop Voice Input"
                                                           action:@selector(stopVoiceInput:)
                                                    keyEquivalent:voiceInputActiveOrPending ? voiceInputShortcutKey : @""];
    stopVoiceItem.target = self;
    stopVoiceItem.keyEquivalentModifierMask = voiceInputActiveOrPending ? voiceInputShortcutModifiers : 0;
    stopVoiceItem.enabled = voiceInputActiveOrPending;
    [menu addItem:stopVoiceItem];

    NSMenuItem *confirmVoiceItem = [[NSMenuItem alloc] initWithTitle:@"Confirm Visible Voice Transcript"
                                                              action:@selector(confirmVoiceTranscript:)
                                                       keyEquivalent:@""];
    confirmVoiceItem.target = self;
    confirmVoiceItem.enabled = self.voiceInputMarkedTextActive;
    [menu addItem:confirmVoiceItem];
    [self addDisabledMenuItemWithTitle:[self voiceInputStatusTitleForMenu] toMenu:menu];
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
    if (self.voiceLiveCandidateVisible && [self.voiceLiveCandidateTexts containsObject:candidateText ?: @""]) {
        NSString *recognizedCandidateText = self.voiceLiveCandidateTexts.firstObject ?: @"";
        NSString *replacementText = self.voiceLiveCandidateReplacementTextsByCandidateText[candidateText ?: @""] ?: candidateText;
        [self.voiceHomophoneStore recordSelectionForCharacter:recognizedCandidateText candidate:candidateText ?: @""];
        [self commitCurrentVoiceTranscriptForReason:@"Candidate" replacementText:replacementText client:[self activeInputClient]];
        return;
    }
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
    self.inputServerActive = YES;
    [self rememberActiveInputClient:sender];
    [self startSecureInputMonitor];
    self.voiceFloatingButton.delegate = self;
    [self syncVoiceFloatingButtonState];
}

- (void)deactivateServer:(id)sender {
    self.lastInputClient = sender ?: self.lastInputClient;
    self.inputServerActive = NO;
    [self stopVoiceInputForReason:@"Input Method Deactivated"];
    if (self.voiceFloatingButton.delegate == self) {
        [self.voiceFloatingButton hide];
    }
    [self stopSecureInputMonitor];
    [self commitComposition:sender];
    [self resetComposition];
    self.lastPrivacyLockBacktickTime = 0;
    self.lastInputClient = nil;
    [super deactivateServer:sender];
}

- (void)hidePalettes {
    self.candidateUpdateSerial += 1;
    self.voiceCandidateUpdateSerial += 1;
    [self.candidatePanel hide];
    [self.candidatePanel clearAnchorSession];
    self.voiceLiveCandidateVisible = NO;
    self.voiceLiveCandidateTexts = @[];
    self.voiceLiveCandidateReplacementTextsByCandidateText = @{};
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

    if ([self firstCurrentCandidateIsQuickPhrase]) {
        [self commitCandidateAtIndex:0 client:sender];
        return YES;
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
        if ([self firstCurrentCandidateIsQuickPhrase]) {
            [self commitCandidate:self.currentCandidates.firstObject client:sender appendText:appendText ?: @""];
            return YES;
        }
        NSString *text = [self.inputState.buffer copy];
        if (appendText.length > 0) {
            text = [text stringByAppendingString:appendText];
        }
        [self commitText:text client:sender resetFirst:YES showAssociations:NO];
        return YES;
    }

    BOOL usingCandidate = self.currentCandidates.count > 0;
    if (usingCandidate) {
        NSUInteger candidateIndex = [self candidateIndexForCurrentCommit];
        MKCandidate *candidate = self.currentCandidates[candidateIndex];
        if ([candidate.source isEqualToString:MKSpellingCandidateSource]) {
            NSString *text = [self.inputState.buffer copy];
            if (appendText.length > 0) {
                text = [text stringByAppendingString:appendText];
            }
            [self commitText:text client:sender resetFirst:YES showAssociations:NO];
            return YES;
        }
        NSString *candidateAppendText = appendOnlyWhenRaw ? @"" : appendText;
        [self commitCandidate:candidate client:sender appendText:candidateAppendText];
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
        [self applyEffectiveInputModeSettings];
        [self resetRecentCommittedText];
        [self resetComposition];
        [self updateComposition];
    }
}

- (BOOL)applyEffectiveInputModeSettings {
    BOOL changed = NO;
    BOOL nextSpacePagingEnabled = [self.preferences effectiveSpacePagingEnabledForMode:self.engineMode];
    if (self.spacePagingEnabled != nextSpacePagingEnabled) {
        _spacePagingEnabled = nextSpacePagingEnabled;
        changed = YES;
    }

    NSUInteger nextCandidatePageSize = [self.preferences effectiveCandidatePageSizeForMode:self.engineMode];
    if (self.candidatePageSize != nextCandidatePageSize) {
        _candidatePageSize = nextCandidatePageSize;
        changed = YES;
    }

    BOOL nextClearReadingOnCompositionFailureEnabled =
        [self.preferences clearReadingOnCompositionFailureEnabledForMode:self.engineMode];
    if (self.clearReadingOnCompositionFailureEnabled != nextClearReadingOnCompositionFailureEnabled) {
        _clearReadingOnCompositionFailureEnabled = nextClearReadingOnCompositionFailureEnabled;
        changed = YES;
    }
    return changed;
}

- (void)applyCandidatePanelPreferences {
    self.candidatePanel.orientation = [self.preferences candidatePanelOrientation];
    self.candidatePanel.candidateFontSize = [self.preferences candidatePanelFontSize];
    self.candidatePanel.highlightColor = [self.preferences candidatePanelHighlightColor];
}

- (void)setEnabledInputModes:(NSArray<NSString *> *)enabledInputModes {
    NSArray<NSString *> *normalizedModes = [PurrTypeInputBehavior normalizedEnabledInputModes:enabledInputModes];
    _enabledInputModes = [normalizedModes copy];
    [self.preferences setEnabledInputModes:normalizedModes];

    if (![self isEnabledEngineMode:self.engineMode]) {
        NSString *fallbackMode = [self.preferences engineMode];
        self.engineMode = fallbackMode;
        [self applyEffectiveInputModeSettings];
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
    [self applyEffectiveInputModeSettings];
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

- (void)voiceFloatingButtonDidRequestToggle:(PurrTypeVoiceFloatingButton *)button {
    if (button != self.voiceFloatingButton || self.voiceFloatingButton.delegate != self) {
        return;
    }
    if ([self isVoiceInputActiveOrPending] || self.voiceInputMarkedTextActive) {
        [self stopVoiceInputForReason:@"Floating Button"];
    } else {
        [self startCantoneseVoiceInput:nil];
    }
}

- (void)syncVoiceFloatingButtonState {
    if (self.voiceFloatingButton.delegate != self) {
        return;
    }
    BOOL blocked = self.privacyLockEnabled || [self isSecureTextInputActive];
    [self.voiceFloatingButton setVoiceInputActive:[self isVoiceInputActiveOrPending]
                                          blocked:blocked
                                      statusTitle:[self voiceInputStatusTitleForMenu]];
    if (!self.inputServerActive || !self.voiceFloatingButtonVisible || [self isSecureTextInputActive]) {
        [self.voiceFloatingButton hide];
        return;
    }
    [self.voiceFloatingButton show];
}

- (void)startCantoneseVoiceInput:(id)sender {
    (void)sender;

    if ([self isVoiceInputActiveOrPending]) {
        return;
    }

    if (self.privacyLockEnabled) {
        self.voiceInputStatusTitle = @"Voice Input: Blocked by Privacy Lock";
        NSBeep();
        [self syncVoiceFloatingButtonState];
        return;
    }

    if ([self isSecureTextInputActive]) {
        self.voiceInputStatusTitle = @"Voice Input: Blocked by Secure Input";
        NSBeep();
        [self syncVoiceFloatingButtonState];
        return;
    }

    if (self.voiceInputMarkedTextActive) {
        [self commitCurrentVoiceTranscriptForReason:@"Confirmed" replacementText:nil client:[self activeInputClient]];
    }

    if ([self hasActiveNonVoiceComposition]) {
        self.voiceInputStatusTitle = @"Voice Input: Finish Current Composition First";
        NSBeep();
        [self syncVoiceFloatingButtonState];
        return;
    }

    self.voiceInputStatusTitle = @"Voice Input: Waiting for Permission";
    self.voiceInputLatestTranscript = nil;
    self.voiceInputLatestRecognitionTranscript = nil;
    self.voiceInputConfirmedRecognitionPrefix = nil;
    self.voiceInputLatestAlternativeTranscripts = @[];
    self.voiceLiveCandidateTexts = @[];
    self.voiceLiveCandidateReplacementTextsByCandidateText = @{};
    self.voiceLiveCandidateVisible = NO;
    self.voiceInputMarkedTextActive = NO;
    self.voiceInputFinalTranscriptCommitted = NO;
    self.voiceInputSessionIdentifier = [NSUUID UUID].UUIDString;

    NSArray<NSString *> *contextualStrings = [self voiceInputContextualStrings];
    [self syncVoiceFloatingButtonState];
    __weak PurrTypeInputController *weakSelf = self;
    NSString *activeSessionIdentifier = [self.voiceInputSessionIdentifier copy];
    BOOL requested = [self.speechInputController startWithLocaleSelectionIdentifier:self.voiceRecognitionLocaleIdentifier
                                                                 contextualStrings:contextualStrings
                                                           transcriptUpdateHandler:^(NSString *transcript, NSArray<NSString *> *alternativeTranscripts, BOOL isFinal) {
        [weakSelf handleVoiceInputTranscript:transcript
                       alternativeTranscripts:alternativeTranscripts
                                      isFinal:isFinal
                            sessionIdentifier:activeSessionIdentifier];
    } errorHandler:^(NSError *error) {
        [weakSelf handleVoiceInputError:error sessionIdentifier:activeSessionIdentifier];
    }];

    if (requested && self.speechInputController.isActive) {
        self.voiceInputStatusTitle = [self voiceInputStatusTitleForMenu];
    } else if (!requested) {
        self.voiceInputSessionIdentifier = nil;
        NSBeep();
    }
    [self syncVoiceFloatingButtonState];
}

- (void)stopVoiceInput:(id)sender {
    (void)sender;
    [self stopVoiceInputForReason:@"User Stopped"];
}

- (void)confirmVoiceTranscript:(id)sender {
    (void)sender;
    [self commitCurrentVoiceTranscriptForReason:@"Confirmed" replacementText:nil client:[self activeInputClient]];
}

- (void)commitCurrentVoiceTranscriptForReason:(NSString *)reason replacementText:(NSString *)replacementText client:(id)sender {
    NSString *sourceText = replacementText.length > 0 ? replacementText : self.voiceInputLatestTranscript;
    NSString *visibleTranscript = [PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:sourceText];
    if (visibleTranscript.length == 0 || !self.voiceInputMarkedTextActive) {
        self.voiceInputStatusTitle = @"Voice Input: No Visible Transcript";
        NSBeep();
        [self syncVoiceFloatingButtonState];
        return;
    }

    id target = sender ?: [self activeInputClient];
    [self clearVoiceInputMarkedTextForClient:target];
    if ([target respondsToSelector:@selector(insertText:replacementRange:)]) {
        [target insertText:visibleTranscript replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    }

    NSString *recognitionPrefix = self.voiceInputLatestRecognitionTranscript.length > 0 ?
        self.voiceInputLatestRecognitionTranscript : visibleTranscript;
    self.voiceInputConfirmedRecognitionPrefix = recognitionPrefix;
    self.voiceInputLatestTranscript = nil;
    self.voiceInputLatestAlternativeTranscripts = @[];
    self.voiceLiveCandidateTexts = @[];
    self.voiceLiveCandidateReplacementTextsByCandidateText = @{};
    self.voiceInputStatusTitle = [reason isEqualToString:@"Candidate"] ?
        @"Voice Input: Candidate Confirmed" : @"Voice Input: Text Confirmed";
    [self syncVoiceFloatingButtonState];
}

- (void)stopVoiceInputForReason:(NSString *)reason {
    BOOL hadVoiceInputActiveOrPending = [self isVoiceInputActiveOrPending];
    if (!hadVoiceInputActiveOrPending && !self.voiceInputMarkedTextActive) {
        return;
    }

    NSString *safeReason = reason.length > 0 ? reason : @"Stopped";
    BOOL shouldCommitLatestTranscript = [self shouldCommitLatestVoiceInputTranscriptWhenStoppingForReason:safeReason];
    BOOL committedLatestTranscript = NO;
    if (shouldCommitLatestTranscript && !self.voiceInputFinalTranscriptCommitted) {
        NSString *latestTranscript = [self.voiceInputLatestTranscript ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (latestTranscript.length > 0) {
            [self commitVoiceFinalTranscript:latestTranscript];
            committedLatestTranscript = YES;
        }
    }

    if (!committedLatestTranscript) {
        [self clearVoiceInputMarkedTextForClient:[self activeInputClient]];
    }
    if (hadVoiceInputActiveOrPending) {
        [self.speechInputController stop];
    }
    if (!committedLatestTranscript) {
        self.voiceInputStatusTitle = [NSString stringWithFormat:@"Voice Input: Stopped (%@)", safeReason];
    }
    self.voiceInputConfirmedRecognitionPrefix = nil;
    self.voiceInputLatestRecognitionTranscript = nil;
    self.voiceInputLatestAlternativeTranscripts = @[];
    self.voiceLiveCandidateTexts = @[];
    self.voiceLiveCandidateReplacementTextsByCandidateText = @{};
    self.voiceInputSessionIdentifier = nil;
    [self syncVoiceFloatingButtonState];
}

- (BOOL)shouldCommitLatestVoiceInputTranscriptWhenStoppingForReason:(NSString *)reason {
    return [reason isEqualToString:@"User Stopped"] ||
           [reason isEqualToString:@"Voice Shortcut"] ||
           [reason isEqualToString:@"Floating Button"];
}

- (BOOL)hasActiveNonVoiceComposition {
    return self.inputState.buffer.length > 0 ||
           self.inputState.associationModeActive ||
           self.punctuationCandidateTexts.count > 0;
}

- (NSArray<NSString *> *)voiceInputContextualStrings {
    return [PurrTypeSpeechInputController contextualStringsFromBundle:[NSBundle mainBundle]
                                                    additionalStrings:[self voiceInputUserContextualStrings]];
}

- (NSArray<NSString *> *)voiceInputUserContextualStrings {
    [self.quickPhraseStore reloadIfChangedWithError:nil];

    NSMutableArray<NSString *> *phrases = [NSMutableArray array];
    NSMutableSet<NSString *> *seenPhrases = [NSMutableSet set];
    for (PurrTypeQuickPhraseEntry *entry in [self.quickPhraseStore entries]) {
        if (!entry.isEnabled) {
            continue;
        }
        NSString *phrase = [self voiceInputContextualPhraseFromString:entry.replacement];
        if (phrase.length == 0 || [seenPhrases containsObject:phrase]) {
            continue;
        }
        [phrases addObject:phrase];
        [seenPhrases addObject:phrase];
        if (phrases.count >= 12) {
            break;
        }
    }
    return [phrases copy];
}

- (NSString *)voiceInputContextualPhraseFromString:(NSString *)text {
    NSString *phrase = [text ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (phrase.length == 0 ||
        [phrase rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound ||
        [phrase rangeOfString:@"@"].location != NSNotFound ||
        [phrase rangeOfString:@"://"].location != NSNotFound ||
        [phrase rangeOfString:@"[\\p{Han}]" options:NSRegularExpressionSearch].location == NSNotFound) {
        return nil;
    }

    __block NSUInteger composedCharacterCount = 0;
    [phrase enumerateSubstringsInRange:NSMakeRange(0, phrase.length)
                               options:NSStringEnumerationByComposedCharacterSequences
                            usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        (void)substring;
        (void)substringRange;
        (void)enclosingRange;
        composedCharacterCount += 1;
        if (composedCharacterCount > 16) {
            *stop = YES;
        }
    }];
    return composedCharacterCount > 16 ? nil : phrase;
}

- (NSArray<NSString *> *)voiceLiveCandidateTextsForAlternatives:(NSArray<NSString *> *)alternativeTranscripts visibleTranscript:(NSString *)visibleTranscript {
    self.voiceLiveCandidateReplacementTextsByCandidateText = @{};
    NSString *normalizedVisibleTranscript = [PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:visibleTranscript];
    if (normalizedVisibleTranscript.length == 0) {
        return @[];
    }

    NSMutableArray<NSString *> *candidateTexts = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSString *> *replacementTexts = [NSMutableDictionary dictionary];
    NSMutableSet<NSString *> *seenTexts = [NSMutableSet set];
    for (NSString *alternative in alternativeTranscripts ?: @[]) {
        NSString *normalizedAlternative = [PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:alternative];
        NSString *visibleAlternative = [self visibleVoiceTranscriptForRecognitionTranscript:normalizedAlternative
                                                                           confirmedPrefix:self.voiceInputConfirmedRecognitionPrefix];
        visibleAlternative = [PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:visibleAlternative];
        if (visibleAlternative.length == 0 || [visibleAlternative isEqualToString:normalizedVisibleTranscript]) {
            continue;
        }

        NSArray<NSString *> *changedSegments = [PurrTypeInputBehavior voiceCandidateChangedSegmentsForVisibleTranscript:normalizedVisibleTranscript
                                                                                                  alternativeTranscript:visibleAlternative
                                                                                                   maximumChangedLength:MKVoiceLiveCandidateMaximumChangedLength];
        if (changedSegments.count != 2) {
            continue;
        }

        NSString *visibleSegment = changedSegments[0];
        NSString *alternativeSegment = changedSegments[1];
        visibleSegment = [PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:visibleSegment];
        alternativeSegment = [PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:alternativeSegment];
        if (visibleSegment.length == 0 || alternativeSegment.length == 0 || [visibleSegment isEqualToString:alternativeSegment]) {
            continue;
        }

        if (![seenTexts containsObject:visibleSegment]) {
            [candidateTexts addObject:visibleSegment];
            replacementTexts[visibleSegment] = normalizedVisibleTranscript;
            [seenTexts addObject:visibleSegment];
        }
        if (![seenTexts containsObject:alternativeSegment]) {
            [candidateTexts addObject:alternativeSegment];
            replacementTexts[alternativeSegment] = visibleAlternative;
            [seenTexts addObject:alternativeSegment];
        }
        if (candidateTexts.count >= MKVoiceLiveCandidateLimit) {
            break;
        }
    }
    if (candidateTexts.count < 2) {
        return [self voiceHomophoneCandidateTextsForVisibleTranscript:normalizedVisibleTranscript];
    }
    self.voiceLiveCandidateReplacementTextsByCandidateText = [replacementTexts copy];
    return [candidateTexts copy];
}

- (NSArray<NSString *> *)voiceHomophoneCandidateTextsForVisibleTranscript:(NSString *)visibleTranscript {
    self.voiceLiveCandidateReplacementTextsByCandidateText = @{};
    NSString *normalizedVisibleTranscript = [PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:visibleTranscript];
    if (normalizedVisibleTranscript.length == 0) {
        return @[];
    }

    NSMutableArray<NSValue *> *characterRanges = [NSMutableArray array];
    [normalizedVisibleTranscript enumerateSubstringsInRange:NSMakeRange(0, normalizedVisibleTranscript.length)
                                                    options:NSStringEnumerationByComposedCharacterSequences
                                                 usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop) {
        (void)substring;
        (void)enclosingRange;
        (void)stop;
        [characterRanges addObject:[NSValue valueWithRange:substringRange]];
    }];

    NSUInteger scannedCount = 0;
    NSString *fallbackRecognizedCharacter = nil;
    for (NSInteger index = (NSInteger)characterRanges.count - 1; index >= 0 && scannedCount < MKVoiceHomophoneFallbackScanLimit; index -= 1, scannedCount += 1) {
        NSRange characterRange = characterRanges[(NSUInteger)index].rangeValue;
        if (characterRange.length == 0 || NSMaxRange(characterRange) > normalizedVisibleTranscript.length) {
            continue;
        }

        NSString *character = [normalizedVisibleTranscript substringWithRange:characterRange];
        if (fallbackRecognizedCharacter.length == 0 &&
            [character rangeOfString:@"^\\p{Han}$" options:NSRegularExpressionSearch].location != NSNotFound) {
            fallbackRecognizedCharacter = character;
        }
        NSArray<NSString *> *homophoneCandidateTexts = [self.voiceHomophoneStore homophonesForCharacter:character
                                                                                                   limit:MKVoiceLiveCandidateLimit];
        NSArray<NSString *> *dictionaryCandidateTexts = [[self engineForInput] dictionaryCandidateTextsForCharacter:character
                                                                                                             limit:MKVoiceLiveCandidateLimit];
        NSMutableArray<NSString *> *candidateTexts = [NSMutableArray arrayWithCapacity:MKVoiceLiveCandidateLimit];
        NSMutableSet<NSString *> *seenCandidateTexts = [NSMutableSet set];
        for (NSArray<NSString *> *sourceCandidateTexts in @[homophoneCandidateTexts, dictionaryCandidateTexts]) {
            for (NSString *candidateText in sourceCandidateTexts) {
                if (candidateText.length == 0 || [seenCandidateTexts containsObject:candidateText]) {
                    continue;
                }
                [candidateTexts addObject:candidateText];
                [seenCandidateTexts addObject:candidateText];
                if (candidateTexts.count >= MKVoiceLiveCandidateLimit) {
                    break;
                }
            }
            if (candidateTexts.count >= MKVoiceLiveCandidateLimit) {
                break;
            }
        }
        if (candidateTexts.count < 2) {
            continue;
        }

        NSString *prefix = [normalizedVisibleTranscript substringToIndex:characterRange.location];
        NSString *suffix = [normalizedVisibleTranscript substringFromIndex:NSMaxRange(characterRange)];
        NSMutableDictionary<NSString *, NSString *> *replacementTexts = [NSMutableDictionary dictionary];
        for (NSString *candidateText in candidateTexts) {
            replacementTexts[candidateText] = [NSString stringWithFormat:@"%@%@%@", prefix, candidateText, suffix];
        }
        self.voiceLiveCandidateReplacementTextsByCandidateText = [replacementTexts copy];
        return candidateTexts;
    }

    if (fallbackRecognizedCharacter.length > 0) {
        self.voiceLiveCandidateReplacementTextsByCandidateText = @{
            fallbackRecognizedCharacter: normalizedVisibleTranscript
        };
        return @[fallbackRecognizedCharacter];
    }

    return @[];
}

- (void)scheduleVoiceLiveCandidates:(NSArray<NSString *> *)candidateTexts nearClient:(id)sender {
    NSUInteger serial = ++self.voiceCandidateUpdateSerial;
    id target = sender ?: [self activeInputClient];
    [self showVoiceLiveCandidates:candidateTexts nearClient:target];
    if (candidateTexts.count == 0) {
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (serial == self.voiceCandidateUpdateSerial) {
            [self showVoiceLiveCandidates:candidateTexts nearClient:target];
        }
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.035 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (serial == self.voiceCandidateUpdateSerial) {
            [self showVoiceLiveCandidates:candidateTexts nearClient:target];
        }
    });
}

- (void)showVoiceLiveCandidates:(NSArray<NSString *> *)candidateTexts nearClient:(id)sender {
    if (candidateTexts.count == 0) {
        [self hideVoiceLiveCandidates];
        return;
    }
    self.voiceLiveCandidateVisible = YES;
    self.voiceLiveCandidateTexts = [candidateTexts copy];
    id target = sender ?: [self activeInputClient];
    NSNumber *anchorCharacterIndex = [self voiceCandidatePanelAnchorCharacterIndex];
    [self.candidatePanel showCandidates:candidateTexts
                              nearClient:target
                    anchorCharacterIndex:anchorCharacterIndex
                               pageIndex:0
                               pageCount:0
                      usePreservedAnchor:NO
                           selectedIndex:0];
    if (!self.candidatePanel.isVisible) {
        [self.candidatePanel showCandidates:candidateTexts
                                  nearClient:target
                        anchorCharacterIndex:nil
                                   pageIndex:0
                                   pageCount:0
                          usePreservedAnchor:YES
                               selectedIndex:0];
    }
    if (!self.candidatePanel.isVisible && self.voiceFloatingButton.isVisible) {
        [self.candidatePanel showCandidates:candidateTexts nearScreenRect:self.voiceFloatingButton.screenFrame];
    }
}

- (NSNumber *)voiceCandidatePanelAnchorCharacterIndex {
    NSString *visibleTranscript = self.voiceInputLatestTranscript ?: @"";
    if (visibleTranscript.length == 0) {
        return nil;
    }
    return @(visibleTranscript.length - 1);
}

- (void)hideVoiceLiveCandidates {
    self.voiceCandidateUpdateSerial += 1;
    if (!self.voiceLiveCandidateVisible) {
        self.voiceLiveCandidateTexts = @[];
        self.voiceLiveCandidateReplacementTextsByCandidateText = @{};
        return;
    }
    self.voiceLiveCandidateVisible = NO;
    self.voiceLiveCandidateTexts = @[];
    self.voiceLiveCandidateReplacementTextsByCandidateText = @{};
    [self.candidatePanel hide];
}

- (NSString *)visibleVoiceTranscriptForRecognitionTranscript:(NSString *)recognitionTranscript {
    return [self visibleVoiceTranscriptForRecognitionTranscript:recognitionTranscript
                                                confirmedPrefix:self.voiceInputConfirmedRecognitionPrefix];
}

- (BOOL)isCurrentVoiceInputSessionIdentifier:(NSString *)sessionIdentifier {
    return sessionIdentifier.length > 0 && [self.voiceInputSessionIdentifier isEqualToString:sessionIdentifier];
}

- (NSString *)visibleVoiceTranscriptForRecognitionTranscript:(NSString *)recognitionTranscript confirmedPrefix:(NSString *)confirmedPrefix {
    NSString *normalizedTranscript = [PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:recognitionTranscript];
    NSString *normalizedPrefix = [PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:confirmedPrefix];
    return [PurrTypeInputBehavior visibleVoiceTranscriptForRecognitionTranscript:normalizedTranscript
                                                                 confirmedPrefix:normalizedPrefix];
}

- (NSString *)stableVoiceVisibleTranscriptForTranscript:(NSString *)visibleTranscript {
    NSString *normalizedTranscript = [PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:visibleTranscript];
    NSString *previousTranscript = [PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:self.voiceInputLatestTranscript];
    return [PurrTypeInputBehavior stableVoiceVisibleTranscriptForTranscript:normalizedTranscript
                                                         previousTranscript:previousTranscript];
}

- (BOOL)isVoiceInputActiveOrPending {
    return self.speechInputController.isActive || self.speechInputController.startInProgress;
}

- (NSString *)voiceInputStatusTitleForMenu {
    if (self.speechInputController.isActive) {
        NSString *localeIdentifier = self.speechInputController.activeLocaleIdentifier ?: @"";
        if (localeIdentifier.length > 0) {
            NSString *localeSelection = self.speechInputController.activeLocaleSelectionIdentifier ?: @"";
            if ([localeSelection isEqualToString:MKVoiceRecognitionLocaleAuto]) {
                return [NSString stringWithFormat:@"Voice Input: Listening (Auto -> %@)", localeIdentifier];
            }
            return [NSString stringWithFormat:@"Voice Input: Listening (%@)", localeIdentifier];
        }
        return @"Voice Input: Listening";
    }

    if (self.speechInputController.startInProgress) {
        return @"Voice Input: Waiting for Permission";
    }

    return self.voiceInputStatusTitle ?: MKVoiceInputStatusReady;
}

- (void)handleVoiceInputTranscript:(NSString *)transcript isFinal:(BOOL)isFinal {
    [self handleVoiceInputTranscript:transcript alternativeTranscripts:@[] isFinal:isFinal];
}

- (void)handleVoiceInputTranscript:(NSString *)transcript alternativeTranscripts:(NSArray<NSString *> *)alternativeTranscripts isFinal:(BOOL)isFinal {
    [self handleVoiceInputTranscript:transcript
               alternativeTranscripts:alternativeTranscripts
                              isFinal:isFinal
                    sessionIdentifier:self.voiceInputSessionIdentifier];
}

- (void)handleVoiceInputTranscript:(NSString *)transcript
             alternativeTranscripts:(NSArray<NSString *> *)alternativeTranscripts
                            isFinal:(BOOL)isFinal
                  sessionIdentifier:(NSString *)sessionIdentifier {
    if (![self isCurrentVoiceInputSessionIdentifier:sessionIdentifier]) {
        return;
    }

    NSString *normalizedRecognitionTranscript = [PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:transcript];
    NSString *visibleTranscript = [self visibleVoiceTranscriptForRecognitionTranscript:normalizedRecognitionTranscript];
    visibleTranscript = [self stableVoiceVisibleTranscriptForTranscript:visibleTranscript];
    self.voiceInputLatestRecognitionTranscript = [PurrTypeInputBehavior voiceRecognitionTranscriptForVisibleTranscript:visibleTranscript
                                                                                                      confirmedPrefix:self.voiceInputConfirmedRecognitionPrefix
                                                                                         fallbackRecognitionTranscript:normalizedRecognitionTranscript];
    self.voiceInputLatestAlternativeTranscripts = alternativeTranscripts ?: @[];
    if (visibleTranscript.length > 0) {
        self.voiceInputLatestTranscript = visibleTranscript;
    }
    if (isFinal) {
        NSArray<NSString *> *finalCandidateTexts = [self voiceLiveCandidateTextsForAlternatives:self.voiceInputLatestAlternativeTranscripts
                                                                              visibleTranscript:visibleTranscript];
        if (finalCandidateTexts.count > 0) {
            [self applyVoicePartialTranscript:visibleTranscript];
            self.voiceInputStatusTitle = @"Voice Input: Choose Candidate";
            [self syncVoiceFloatingButtonState];
            return;
        }
        [self commitVoiceFinalTranscript:visibleTranscript];
        return;
    }

    [self applyVoicePartialTranscript:visibleTranscript];
}

- (void)applyVoicePartialTranscript:(NSString *)transcript {
    id target = [self activeInputClient];
    if (![target respondsToSelector:@selector(setMarkedText:selectionRange:replacementRange:)]) {
        return;
    }

    NSString *normalizedTranscript = [PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:transcript];
    if (normalizedTranscript.length == 0) {
        self.voiceInputLatestTranscript = nil;
        [self clearVoiceInputMarkedTextForClient:target];
        [self hideVoiceLiveCandidates];
        [self syncVoiceFloatingButtonState];
        return;
    }

    self.voiceInputLatestTranscript = normalizedTranscript;
    if (!self.voiceInputMarkedTextActive) {
        [self.candidatePanel beginAnchorSessionForClient:target];
    }
    [target setMarkedText:normalizedTranscript
           selectionRange:NSMakeRange(normalizedTranscript.length, 0)
         replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    self.voiceInputMarkedTextActive = YES;
    self.voiceInputStatusTitle = [self voiceInputStatusTitleForMenu];
    NSArray<NSString *> *candidateTexts = [self voiceLiveCandidateTextsForAlternatives:self.voiceInputLatestAlternativeTranscripts
                                                                     visibleTranscript:normalizedTranscript];
    [self scheduleVoiceLiveCandidates:candidateTexts nearClient:target];
    [self syncVoiceFloatingButtonState];
}

- (void)commitVoiceFinalTranscript:(NSString *)transcript {
    if (self.voiceInputFinalTranscriptCommitted) {
        return;
    }
    self.voiceInputFinalTranscriptCommitted = YES;

    id target = [self activeInputClient];
    [self clearVoiceInputMarkedTextForClient:target];

    NSString *finalTranscript = [PurrTypeSpeechInputController normalizedVoiceTranscriptForVoiceInput:transcript];
    if (finalTranscript.length == 0) {
        self.voiceInputStatusTitle = self.voiceInputConfirmedRecognitionPrefix.length > 0 ?
            @"Voice Input: Final Text Already Confirmed" : @"Voice Input: No Speech Recognized";
        self.voiceInputConfirmedRecognitionPrefix = nil;
        self.voiceInputLatestRecognitionTranscript = nil;
        self.voiceInputLatestAlternativeTranscripts = @[];
        self.voiceInputSessionIdentifier = nil;
        [self syncVoiceFloatingButtonState];
        return;
    }

    self.voiceInputLatestTranscript = finalTranscript;
    if ([target respondsToSelector:@selector(insertText:replacementRange:)]) {
        [target insertText:finalTranscript replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    }
    self.voiceInputConfirmedRecognitionPrefix = nil;
    self.voiceInputLatestRecognitionTranscript = nil;
    self.voiceInputLatestAlternativeTranscripts = @[];
    self.voiceInputStatusTitle = @"Voice Input: Final Text Committed";
    self.voiceInputSessionIdentifier = nil;
    [self syncVoiceFloatingButtonState];
}

- (void)clearVoiceInputMarkedTextForClient:(id)sender {
    if (!self.voiceInputMarkedTextActive) {
        [self hideVoiceLiveCandidates];
        return;
    }

    id target = sender ?: [self activeInputClient];
    if ([target respondsToSelector:@selector(setMarkedText:selectionRange:replacementRange:)]) {
        [target setMarkedText:@""
               selectionRange:NSMakeRange(0, 0)
             replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    }
    self.voiceInputMarkedTextActive = NO;
    [self hideVoiceLiveCandidates];
    [self syncVoiceFloatingButtonState];
}

- (void)handleVoiceInputError:(NSError *)error {
    [self handleVoiceInputError:error sessionIdentifier:self.voiceInputSessionIdentifier];
}

- (void)handleVoiceInputError:(NSError *)error sessionIdentifier:(NSString *)sessionIdentifier {
    if (![self isCurrentVoiceInputSessionIdentifier:sessionIdentifier]) {
        return;
    }

    [self clearVoiceInputMarkedTextForClient:[self activeInputClient]];
    self.voiceInputSessionIdentifier = nil;
    self.voiceInputLatestTranscript = nil;
    self.voiceInputLatestRecognitionTranscript = nil;
    self.voiceInputConfirmedRecognitionPrefix = nil;
    self.voiceInputLatestAlternativeTranscripts = @[];
    NSString *message = error.localizedDescription ?: @"Unavailable";
    self.voiceInputStatusTitle = [NSString stringWithFormat:@"Voice Input: %@", message];
    NSLog(@"PurrType voice input failed: %@", message);
    [self syncVoiceFloatingButtonState];
}

- (void)setLearningEnabled:(BOOL)enabled {
    [self.preferences setLearningEnabled:enabled];
    [self applyEffectiveLearningState];
    [self resetRecentCommittedText];
    [self resetComposition];
    [self updateComposition];
    [self syncVoiceFloatingButtonState];
}

- (void)setPrivacyLockEnabled:(BOOL)enabled {
    if (enabled) {
        [self stopVoiceInputForReason:@"Privacy Lock"];
    }
    _privacyLockEnabled = enabled;
    [self.preferences setPrivacyLockEnabled:enabled];
    [self applyEffectiveLearningState];
    [self resetRecentCommittedText];
    [self resetComposition];
    [self updateComposition];
    [self syncVoiceFloatingButtonState];
}

- (BOOL)effectiveLearningEnabledFromPreferences {
    return !self.privacyLockEnabled && [self.preferences learningEnabled];
}

- (void)applyEffectiveLearningState {
    if (self.engine) {
        self.engine.learningEnabled = [self effectiveLearningEnabledFromPreferences];
    }
    self.voiceHomophoneStore.learningEnabled = [self effectiveLearningEnabledFromPreferences];
}

- (void)setRawEnglishCandidateEnabled:(BOOL)enabled {
    _rawEnglishCandidateEnabled = enabled;
    [self.preferences setRawEnglishCandidateEnabled:enabled];
    [self setCandidatePool:self.candidatePool resetPage:NO];
    [self updateComposition];
}

- (void)setRawEnglishCandidatePosition:(NSString *)position {
    NSString *normalizedPosition = [position isEqualToString:MKRawEnglishCandidatePositionTrailing] ?
        MKRawEnglishCandidatePositionTrailing : MKRawEnglishCandidatePositionLeading;
    _rawEnglishCandidatePosition = normalizedPosition;
    [self.preferences setRawEnglishCandidatePosition:normalizedPosition];
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
    [self.preferences setSpacePagingEnabled:enabled];
    [self applyEffectiveInputModeSettings];
}

- (void)setDecimalPointShortcutEnabled:(BOOL)enabled {
    _decimalPointShortcutEnabled = enabled;
    [self.preferences setDecimalPointShortcutEnabled:enabled];
}

- (void)setChineseContextPunctuationEnabled:(BOOL)enabled {
    _chineseContextPunctuationEnabled = enabled;
    [self.preferences setChineseContextPunctuationEnabled:enabled];
    if (self.punctuationCandidateTexts.count > 0) {
        [self clearPunctuationCandidates];
    }
}

- (void)setCandidatePageSize:(NSUInteger)pageSize {
    if (pageSize != 5 && pageSize != 9) {
        pageSize = [PurrTypeInputBehavior candidatePageSize];
    }

    [self.preferences setCandidatePageSize:pageSize];
    [self applyEffectiveInputModeSettings];
    [self setCandidatePool:self.candidatePool resetPage:NO];
    [self updateComposition];
}

- (void)setCandidatePanelOrientation:(NSString *)orientation {
    [self.preferences setCandidatePanelOrientation:orientation];
    [self applyCandidatePanelPreferences];
    [self updateCandidatePanel];
}

- (void)setCandidatePanelFontSize:(CGFloat)fontSize {
    [self.preferences setCandidatePanelFontSize:fontSize];
    [self applyCandidatePanelPreferences];
    [self updateCandidatePanel];
}

- (void)setCandidatePanelHighlightColor:(NSString *)highlightColor {
    [self.preferences setCandidatePanelHighlightColor:highlightColor];
    [self applyCandidatePanelPreferences];
    [self updateCandidatePanel];
}

- (void)setAssociationCandidatesEnabled:(BOOL)enabled {
    _associationCandidatesEnabled = enabled;
    [self.preferences setAssociationCandidatesEnabled:enabled];
    if (!enabled && self.inputState.associationModeActive) {
        [self clearAssociations];
    }
}

- (void)setAssociationContinuationEnabled:(BOOL)enabled {
    _associationContinuationEnabled = enabled;
    [self.preferences setAssociationContinuationEnabled:enabled];
}

- (void)setClearReadingOnCompositionFailureEnabled:(BOOL)enabled forMode:(NSString *)mode {
    [self.preferences setClearReadingOnCompositionFailureEnabled:enabled forMode:mode];
    if ([mode isEqualToString:self.engineMode]) {
        _clearReadingOnCompositionFailureEnabled = enabled;
    }
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

- (void)setVoiceRecognitionLocaleIdentifier:(NSString *)localeIdentifier {
    _voiceRecognitionLocaleIdentifier = [[PurrTypeSpeechInputController normalizedLocaleSelectionIdentifier:localeIdentifier] copy];
    [self.preferences setVoiceRecognitionLocaleIdentifier:self.voiceRecognitionLocaleIdentifier];
    if (![self isVoiceInputActiveOrPending]) {
        self.voiceInputStatusTitle = MKVoiceInputStatusReady;
    }
    [self syncVoiceFloatingButtonState];
}

- (void)setVoiceFloatingButtonVisible:(BOOL)visible {
    _voiceFloatingButtonVisible = visible;
    [self.preferences setVoiceFloatingButtonVisible:visible];
    [self syncVoiceFloatingButtonState];
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
    id nextClient = sender ?: [self client];
    if (nextClient && self.lastInputClient && self.lastInputClient != nextClient) {
        [self clearTransientInputStateAfterClientChange];
    }
    self.lastInputClient = nextClient;
}

- (void)clearTransientInputStateAfterClientChange {
    [self resetComposition];
    [self clearTextContextFallback];
    self.voiceCandidateUpdateSerial += 1;
    self.voiceLiveCandidateVisible = NO;
    self.voiceLiveCandidateTexts = @[];
    self.voiceLiveCandidateReplacementTextsByCandidateText = @{};
}

- (NSString *)activeApplicationBundleIdentifier {
    return MKFrontmostApplicationBundleIdentifier();
}

- (BOOL)shouldBypassFinderNonTextInputForString:(NSString *)string client:(id)sender {
    return [PurrTypeInputBehavior shouldBypassFinderNonTextInputForBundleIdentifier:[self activeApplicationBundleIdentifier]
                                                                        inputString:string
                                                            hasTextInsertionContext:[self hasTextInsertionContextForClient:sender]
                                                               hasActiveComposition:[self hasActiveMarkedCompositionForFinderBypass]];
}

- (BOOL)hasActiveMarkedCompositionForFinderBypass {
    return self.inputState.buffer.length > 0 ||
           self.punctuationAnchorText.length > 0 ||
           self.voiceInputMarkedTextActive;
}

- (void)clearTransientInputStateForFinderBypass {
    [self resetComposition];
    [self clearTextContextFallback];
    self.voiceCandidateUpdateSerial += 1;
    self.voiceLiveCandidateVisible = NO;
    self.voiceLiveCandidateTexts = @[];
    self.voiceLiveCandidateReplacementTextsByCandidateText = @{};
}

- (BOOL)hasTextInsertionContextForClient:(id)sender {
    id target = sender ?: [self activeInputClient];
    if (!target) {
        return NO;
    }

    if ([target respondsToSelector:@selector(markedRange)]) {
        NSRange markedRange = [(id<NSTextInputClient>)target markedRange];
        if (markedRange.location != NSNotFound) {
            return YES;
        }
    }

    if (![target respondsToSelector:@selector(selectedRange)]) {
        return NO;
    }

    NSRange selectedRange = [(id<NSTextInputClient>)target selectedRange];
    if (selectedRange.location == NSNotFound) {
        return NO;
    }

    return selectedRange.length > 0 ||
           [self hasTextAroundSelectedRange:selectedRange client:target] ||
           [self hasUsableTextCaretRectForSelectedRange:selectedRange client:target];
}

- (BOOL)hasTextAroundSelectedRange:(NSRange)selectedRange client:(id)sender {
    id target = sender ?: [self activeInputClient];
    if (![target respondsToSelector:@selector(attributedSubstringForProposedRange:actualRange:)]) {
        return NO;
    }

    NSRange proposedRange = selectedRange.location > 0 ?
        NSMakeRange(selectedRange.location - 1, 1) :
        NSMakeRange(0, 1);
    NSRange actualRange = NSMakeRange(NSNotFound, 0);
    NSAttributedString *substring = [(id<NSTextInputClient>)target attributedSubstringForProposedRange:proposedRange
                                                                                           actualRange:&actualRange];
    return actualRange.location != NSNotFound && substring.string.length > 0;
}

- (BOOL)hasUsableTextCaretRectForSelectedRange:(NSRange)selectedRange client:(id)sender {
    id target = sender ?: [self activeInputClient];
    if (![target respondsToSelector:@selector(firstRectForCharacterRange:actualRange:)]) {
        return NO;
    }

    NSRange actualRange = NSMakeRange(NSNotFound, 0);
    NSRect rect = [(id<NSTextInputClient>)target firstRectForCharacterRange:selectedRange actualRange:&actualRange];
    return [self isUsableTextCaretRect:rect selectedRange:selectedRange];
}

- (BOOL)isUsableTextCaretRect:(NSRect)rect selectedRange:(NSRange)selectedRange {
    if (NSEqualRects(rect, NSZeroRect) ||
        !isfinite(NSMinX(rect)) ||
        !isfinite(NSMinY(rect)) ||
        !isfinite(NSWidth(rect)) ||
        !isfinite(NSHeight(rect)) ||
        NSWidth(rect) < 0.0 ||
        NSHeight(rect) < 0.0) {
        return NO;
    }

    NSRect normalizedRect = NSMakeRect(NSMinX(rect),
                                       NSMinY(rect),
                                       NSWidth(rect) <= 0.0 ? 1.0 : NSWidth(rect),
                                       NSHeight(rect) <= 0.0 ? 1.0 : NSHeight(rect));
    NSPoint point = NSMakePoint(NSMidX(normalizedRect), NSMidY(normalizedRect));
    for (NSScreen *screen in [NSScreen screens]) {
        if (!NSPointInRect(point, screen.frame)) {
            continue;
        }

        BOOL isScreenLeftZeroRange = selectedRange.location == 0 &&
                                     selectedRange.length == 0 &&
                                     fabs(NSMinX(normalizedRect) - NSMinX(screen.frame)) <= 2.0;
        return !isScreenLeftZeroRange;
    }
    return NO;
}

- (void)handlePreferencesChanged:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL shouldResetLearning = [notification.userInfo[MKPreferencesResetLearningKey] boolValue] ||
                                   [self.preferences hasPendingLearningReset];
        BOOL quickPhrasesChanged = [notification.userInfo[MKPreferencesQuickPhrasesChangedKey] boolValue];
        if (quickPhrasesChanged) {
            [self.quickPhraseStore loadWithError:nil];
            if (self.inputState.rawEnglishModeActive && self.inputState.buffer.length > 0) {
                [self refreshRawEnglishSuggestionsResetPage:YES];
                [self updateComposition];
            }
        }
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

        NSString *nextRawEnglishCandidatePosition = [self.preferences rawEnglishCandidatePosition];
        if (![self.rawEnglishCandidatePosition isEqualToString:nextRawEnglishCandidatePosition]) {
            _rawEnglishCandidatePosition = nextRawEnglishCandidatePosition;
            [self setCandidatePool:self.candidatePool resetPage:NO];
            [self updateComposition];
        }

        BOOL nextDecimalPointShortcutEnabled = [self.preferences decimalPointShortcutEnabled];
        if (self.decimalPointShortcutEnabled != nextDecimalPointShortcutEnabled) {
            _decimalPointShortcutEnabled = nextDecimalPointShortcutEnabled;
        }

        BOOL nextChineseContextPunctuationEnabled = [self.preferences chineseContextPunctuationEnabled];
        if (self.chineseContextPunctuationEnabled != nextChineseContextPunctuationEnabled) {
            _chineseContextPunctuationEnabled = nextChineseContextPunctuationEnabled;
            if (self.punctuationCandidateTexts.count > 0) {
                [self clearPunctuationCandidates];
            }
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

        BOOL inputModeSettingsChanged = [self applyEffectiveInputModeSettings];
        [self applyCandidatePanelPreferences];

        BOOL nextAssociationCandidatesEnabled = [self.preferences associationCandidatesEnabled];
        BOOL nextAssociationContinuationEnabled = [self.preferences associationContinuationEnabled];
        BOOL associationSettingsChanged =
            self.associationCandidatesEnabled != nextAssociationCandidatesEnabled ||
            self.associationContinuationEnabled != nextAssociationContinuationEnabled;
        if (associationSettingsChanged) {
            _associationCandidatesEnabled = nextAssociationCandidatesEnabled;
            _associationContinuationEnabled = nextAssociationContinuationEnabled;
            if (!self.associationCandidatesEnabled && self.inputState.associationModeActive) {
                [self clearAssociations];
            }
        }

        if (inputModeSettingsChanged) {
            if (self.inputState.buffer.length > 0) {
                if (self.inputState.rawEnglishModeActive) {
                    [self refreshRawEnglishSuggestionsResetPage:YES];
                } else {
                    [self refreshCandidates];
                }
            } else {
                [self setCandidatePool:self.candidatePool resetPage:NO];
            }
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
        NSString *nextVoiceRecognitionLocaleIdentifier = [self.preferences voiceRecognitionLocaleIdentifier];
        if (![self.voiceRecognitionLocaleIdentifier isEqualToString:nextVoiceRecognitionLocaleIdentifier]) {
            _voiceRecognitionLocaleIdentifier = [nextVoiceRecognitionLocaleIdentifier copy];
        }
        BOOL nextVoiceFloatingButtonVisible = [self.preferences voiceFloatingButtonVisible];
        if (self.voiceFloatingButtonVisible != nextVoiceFloatingButtonVisible) {
            _voiceFloatingButtonVisible = nextVoiceFloatingButtonVisible;
        }
        _modeShortcutsByMode = [[self.preferences modeShortcutsByMode] copy];
        [self syncVoiceFloatingButtonState];

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

- (NSString *)preferencesRawEnglishCandidatePosition {
    return self.rawEnglishCandidatePosition ?: MKRawEnglishCandidatePositionLeading;
}

- (void)preferencesSetRawEnglishCandidatePosition:(NSString *)position {
    [self setRawEnglishCandidatePosition:position];
}

- (BOOL)preferencesSpellingSuggestionsEnabled {
    return self.spellingSuggestionsEnabled;
}

- (void)preferencesSetSpellingSuggestionsEnabled:(BOOL)enabled {
    [self setSpellingSuggestionsEnabled:enabled];
}

- (BOOL)preferencesSpacePagingEnabled {
    return [self.preferences spacePagingEnabled];
}

- (void)preferencesSetSpacePagingEnabled:(BOOL)enabled {
    [self setSpacePagingEnabled:enabled];
}

- (BOOL)preferencesDecimalPointShortcutEnabled {
    return self.decimalPointShortcutEnabled;
}

- (void)preferencesSetDecimalPointShortcutEnabled:(BOOL)enabled {
    [self setDecimalPointShortcutEnabled:enabled];
}

- (BOOL)preferencesChineseContextPunctuationEnabled {
    return self.chineseContextPunctuationEnabled;
}

- (void)preferencesSetChineseContextPunctuationEnabled:(BOOL)enabled {
    [self setChineseContextPunctuationEnabled:enabled];
}

- (NSUInteger)preferencesCandidatePageSize {
    return [self.preferences candidatePageSize];
}

- (void)preferencesSetCandidatePageSize:(NSUInteger)pageSize {
    [self setCandidatePageSize:pageSize];
}

- (NSString *)preferencesCandidatePanelOrientation {
    return [self.preferences candidatePanelOrientation];
}

- (void)preferencesSetCandidatePanelOrientation:(NSString *)orientation {
    [self setCandidatePanelOrientation:orientation];
}

- (CGFloat)preferencesCandidatePanelFontSize {
    return [self.preferences candidatePanelFontSize];
}

- (void)preferencesSetCandidatePanelFontSize:(CGFloat)fontSize {
    [self setCandidatePanelFontSize:fontSize];
}

- (NSString *)preferencesCandidatePanelHighlightColor {
    return [self.preferences candidatePanelHighlightColor];
}

- (void)preferencesSetCandidatePanelHighlightColor:(NSString *)highlightColor {
    [self setCandidatePanelHighlightColor:highlightColor];
}

- (BOOL)preferencesAssociationCandidatesEnabled {
    return self.associationCandidatesEnabled;
}

- (void)preferencesSetAssociationCandidatesEnabled:(BOOL)enabled {
    [self setAssociationCandidatesEnabled:enabled];
}

- (BOOL)preferencesAssociationContinuationEnabled {
    return self.associationContinuationEnabled;
}

- (void)preferencesSetAssociationContinuationEnabled:(BOOL)enabled {
    [self setAssociationContinuationEnabled:enabled];
}

- (NSUInteger)preferencesCandidatePageSizeOverrideForMode:(NSString *)mode {
    return [self.preferences candidatePageSizeOverrideForMode:mode];
}

- (void)preferencesSetCandidatePageSizeOverride:(NSUInteger)pageSize forMode:(NSString *)mode {
    [self.preferences setCandidatePageSizeOverride:pageSize forMode:mode];
    if ([mode isEqualToString:self.engineMode] && [self applyEffectiveInputModeSettings]) {
        [self setCandidatePool:self.candidatePool resetPage:NO];
        [self updateComposition];
    }
}

- (NSString *)preferencesSpaceKeyOverrideForMode:(NSString *)mode {
    return [self.preferences spaceKeyOverrideForMode:mode];
}

- (void)preferencesSetSpaceKeyOverride:(NSString *)overrideValue forMode:(NSString *)mode {
    [self.preferences setSpaceKeyOverride:overrideValue forMode:mode];
    if ([mode isEqualToString:self.engineMode]) {
        [self applyEffectiveInputModeSettings];
    }
}

- (BOOL)preferencesClearReadingOnCompositionFailureEnabledForMode:(NSString *)mode {
    return [self.preferences clearReadingOnCompositionFailureEnabledForMode:mode];
}

- (void)preferencesSetClearReadingOnCompositionFailureEnabled:(BOOL)enabled forMode:(NSString *)mode {
    [self setClearReadingOnCompositionFailureEnabled:enabled forMode:mode];
    if ([mode isEqualToString:self.engineMode] && self.inputState.buffer.length > 0) {
        if (self.inputState.rawEnglishModeActive) {
            [self refreshRawEnglishSuggestionsResetPage:YES];
        } else {
            [self refreshCandidates];
        }
        [self updateComposition];
    }
}

- (void)preferencesResetOverridesForMode:(NSString *)mode {
    [self.preferences resetOverridesForMode:mode];
    if ([mode isEqualToString:self.engineMode]) {
        BOOL inputModeSettingsChanged = [self applyEffectiveInputModeSettings];
        if (inputModeSettingsChanged || self.inputState.buffer.length > 0) {
            if (self.inputState.rawEnglishModeActive) {
                [self refreshRawEnglishSuggestionsResetPage:YES];
            } else if (self.inputState.buffer.length > 0) {
                [self refreshCandidates];
            } else {
                [self setCandidatePool:self.candidatePool resetPage:NO];
            }
            [self updateComposition];
        }
    }
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

- (NSString *)preferencesVoiceRecognitionLocaleIdentifier {
    return self.voiceRecognitionLocaleIdentifier ?: MKVoiceRecognitionLocaleAuto;
}

- (void)preferencesSetVoiceRecognitionLocaleIdentifier:(NSString *)localeIdentifier {
    [self setVoiceRecognitionLocaleIdentifier:localeIdentifier];
}

- (BOOL)preferencesVoiceFloatingButtonVisible {
    return self.voiceFloatingButtonVisible;
}

- (void)preferencesSetVoiceFloatingButtonVisible:(BOOL)visible {
    [self setVoiceFloatingButtonVisible:visible];
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

- (BOOL)handleVoiceInputShortcutForKey:(NSInteger)keyCode modifiers:(NSUInteger)flags client:(id)sender {
    (void)sender;
    if (![PurrTypeInputBehavior isVoiceInputShortcutKeyCode:keyCode modifiers:flags]) {
        return NO;
    }

    if ([self isVoiceInputActiveOrPending] || self.voiceInputMarkedTextActive) {
        [self stopVoiceInputForReason:@"Voice Shortcut"];
    } else {
        [self startCantoneseVoiceInput:nil];
    }
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
    if ([self shouldShowRawEnglishCandidate] &&
        ![self.rawEnglishCandidatePosition isEqualToString:MKRawEnglishCandidatePositionTrailing]) {
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

- (NSArray<MKCandidate *> *)quickPhraseCandidatesForCurrentBuffer {
    NSString *trigger = self.inputState.buffer ?: @"";
    if (![PurrTypeQuickPhraseStore isValidTrigger:trigger]) {
        return @[];
    }

    [self.quickPhraseStore reloadIfChangedWithError:nil];
    NSArray<PurrTypeQuickPhraseEntry *> *entries = [self.quickPhraseStore enabledEntriesForTrigger:trigger];
    if (entries.count == 0) {
        return @[];
    }

    NSMutableArray<MKCandidate *> *candidates = [NSMutableArray arrayWithCapacity:entries.count];
    NSInteger weight = 1000;
    for (PurrTypeQuickPhraseEntry *entry in entries) {
        [candidates addObject:[[MKCandidate alloc] initWithText:entry.replacement
                                                           code:entry.normalizedTrigger
                                                         source:MKQuickPhraseCandidateSource
                                                         weight:weight]];
        weight -= 1;
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

- (BOOL)firstCurrentCandidateIsQuickPhrase {
    MKCandidate *candidate = self.currentCandidates.firstObject;
    return [candidate.source isEqualToString:MKQuickPhraseCandidateSource];
}

- (BOOL)firstCurrentCandidateIsSpellingSuggestion {
    MKCandidate *candidate = self.currentCandidates.firstObject;
    return [candidate.source isEqualToString:MKSpellingCandidateSource];
}

- (void)refreshRawEnglishSuggestionsResetPage:(BOOL)resetPage {
    NSArray<MKCandidate *> *quickPhraseCandidates = [self quickPhraseCandidatesForCurrentBuffer];
    [self setCandidatePool:(quickPhraseCandidates.count > 0 ? quickPhraseCandidates : [self spellingSuggestionCandidatesForCurrentBuffer])
                 resetPage:resetPage];
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
                                   rawEnglishCandidateEnabled:YES
                                  rawEnglishCandidatePosition:self.rawEnglishCandidatePosition];
    }

    return [PurrTypeInputBehavior displayTextsForCandidates:self.currentCandidates
                                                    buffer:self.inputState.buffer ?: @""
                                      rawEnglishModeActive:self.inputState.rawEnglishModeActive
                                     associationModeActive:self.inputState.associationModeActive
                               rawEnglishCandidateEnabled:self.rawEnglishCandidateEnabled
                              rawEnglishCandidatePosition:self.rawEnglishCandidatePosition];
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

    BOOL didInsertText = NO;
    if ([target respondsToSelector:@selector(insertText:replacementRange:)]) {
        [target insertText:text replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
        didInsertText = YES;
    }

    if (!resetFirst) {
        [self resetCompositionPreservingCandidateAnchor:effectiveShowAssociations];
    }

    if (didInsertText) {
        [self rememberTextContextFallback:text client:target];
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
    [self clearTextContextFallback];
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
    if ([candidate.source isEqualToString:MKQuickPhraseCandidateSource]) {
        NSString *text = candidate.text ?: @"";
        if (appendText.length > 0) {
            text = [text stringByAppendingString:appendText];
        }
        [self commitText:text client:sender resetFirst:YES showAssociations:NO];
        self.lastCommittedCandidateText = nil;
        [self resetRecentCommittedText];
        return;
    }

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
    BOOL isAssociationCandidate = self.inputState.associationModeActive;
    BOOL shouldShowAssociations = appendText.length == 0 &&
                                  self.associationCandidatesEnabled &&
                                  (!isAssociationCandidate || self.associationContinuationEnabled) &&
                                  ![self privacyLockPausesLearningContextForMode:self.engineMode];
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

- (void)rememberTextContextFallback:(NSString *)text client:(id)sender {
    id target = sender ?: [self activeInputClient];
    if (!target || text.length == 0) {
        [self clearTextContextFallback];
        return;
    }

    NSRange lastCharacterRange = [text rangeOfComposedCharacterSequenceAtIndex:text.length - 1];
    self.lastTextContextFallbackText = [text substringWithRange:lastCharacterRange];
    self.lastTextContextFallbackClient = target;
}

- (void)recordPassthroughTextContextForString:(NSString *)string client:(id)sender {
    if (string.length != 1 ||
        [string rangeOfCharacterFromSet:[NSCharacterSet controlCharacterSet]].location != NSNotFound ||
        [string rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]].location != NSNotFound) {
        [self clearTextContextFallback];
        return;
    }

    [self rememberTextContextFallback:string client:sender];
}

- (NSString *)textContextFallbackForClient:(id)sender {
    id target = sender ?: [self activeInputClient];
    if (!target || !self.lastTextContextFallbackClient || self.lastTextContextFallbackClient != target) {
        return @"";
    }
    return self.lastTextContextFallbackText ?: @"";
}

- (void)clearTextContextFallback {
    self.lastTextContextFallbackText = @"";
    self.lastTextContextFallbackClient = nil;
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
    [self stopVoiceInputForReason:@"Secure Input"];
    [self.voiceFloatingButton hide];
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
    id target = sender ?: [self activeInputClient];
    NSString *contextText = [self punctuationContextTextForClient:target];
    if (self.decimalPointShortcutEnabled &&
        [string isEqualToString:@"."] &&
        [PurrTypeInputBehavior textEndsWithDecimalDigit:contextText]) {
        return [self insertLiteralPunctuationText:@"." client:target];
    }

    BOOL preferChineseDefault = self.chineseContextPunctuationEnabled &&
        [PurrTypeInputBehavior textEndsWithChineseCharacter:contextText];
    NSArray<NSString *> *displayTexts = [PurrTypeInputBehavior punctuationCandidateDisplayTextsForString:string ?: @""
                                                                                    preferChineseDefault:preferChineseDefault];
    if (displayTexts.count == 0) {
        return NO;
    }

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

- (NSString *)punctuationContextTextForClient:(id)sender {
    if (self.inputState.buffer.length > 0) {
        if (!self.inputState.rawEnglishModeActive && self.currentCandidates.count > 0) {
            NSUInteger candidateIndex = [self candidateIndexForCurrentCommit];
            if (candidateIndex < self.currentCandidates.count) {
                MKCandidate *candidate = self.currentCandidates[candidateIndex];
                BOOL isRawEnglishAssistCandidate =
                    [candidate.source isEqualToString:MKQuickPhraseCandidateSource] ||
                    [candidate.source isEqualToString:MKSpellingCandidateSource];
                if (!isRawEnglishAssistCandidate) {
                    return candidate.text ?: @"";
                }
            }
        }
        return self.inputState.buffer ?: @"";
    }

    NSString *clientContext = [self textBeforeInsertionPointForClient:sender maximumLength:4];
    if (clientContext.length > 0) {
        return clientContext;
    }

    NSString *fallbackContext = [self textContextFallbackForClient:sender];
    if (fallbackContext.length > 0) {
        return fallbackContext;
    }

    return self.lastCommittedCandidateText ?: @"";
}

- (NSString *)textBeforeInsertionPointForClient:(id)sender maximumLength:(NSUInteger)maximumLength {
    id target = sender ?: [self activeInputClient];
    if (maximumLength == 0 ||
        ![target respondsToSelector:@selector(selectedRange)] ||
        ![target respondsToSelector:@selector(attributedSubstringForProposedRange:actualRange:)]) {
        return @"";
    }

    NSRange selectedRange = [(id<NSTextInputClient>)target selectedRange];
    if (selectedRange.location == NSNotFound || selectedRange.location == 0) {
        return @"";
    }

    NSUInteger length = MIN(maximumLength, selectedRange.location);
    NSRange proposedRange = NSMakeRange(selectedRange.location - length, length);
    NSAttributedString *substring = [(id<NSTextInputClient>)target attributedSubstringForProposedRange:proposedRange
                                                                                           actualRange:NULL];
    NSString *text = substring.string ?: @"";
    if (text.length == 0) {
        return @"";
    }

    NSRange lastCharacterRange = [text rangeOfComposedCharacterSequenceAtIndex:text.length - 1];
    return [text substringWithRange:lastCharacterRange];
}

- (BOOL)insertLiteralPunctuationText:(NSString *)text client:(id)sender {
    if (text.length == 0) {
        return NO;
    }
    id target = sender ?: [self activeInputClient];
    if (![target respondsToSelector:@selector(insertText:replacementRange:)]) {
        return NO;
    }
    if (self.inputState.associationModeActive) {
        [self clearAssociations];
    }
    [target insertText:text replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
    [self rememberTextContextFallback:text client:target];
    self.lastCommittedCandidateText = nil;
    [self resetRecentCommittedText];
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

- (BOOL)convertSemicolonPunctuationToQuickPhraseWithString:(NSString *)string client:(id)sender {
    if (![self.punctuationAnchorText isEqualToString:@";"] ||
        ![PurrTypeQuickPhraseStore isTriggerContinuationString:string]) {
        return NO;
    }

    id target = sender ?: [self activeInputClient];
    self.punctuationCandidateTexts = @[];
    self.punctuationAnchorText = @"";
    self.candidateUpdateSerial += 1;
    [self.inputState resetComposition];
    [self.inputState appendRawEnglishText:@";"];
    [self.inputState appendRawEnglishText:string ?: @""];
    [self refreshRawEnglishSuggestionsResetPage:YES];
    [self beginCandidateAnchorSessionForClient:target];
    [self updateComposition];
    return YES;
}

- (void)commitCurrentCompositionWithoutAssociationsForClient:(id)sender {
    if (self.inputState.buffer.length == 0) {
        return;
    }

    if (self.currentCandidates.count > 0) {
        NSUInteger candidateIndex = [self candidateIndexForCurrentCommit];
        MKCandidate *candidate = self.currentCandidates[candidateIndex];
        if ([candidate.source isEqualToString:MKQuickPhraseCandidateSource]) {
            [self commitCandidateAtIndex:candidateIndex client:sender];
            return;
        }

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
    self.selectedCandidateIndex = 0;
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
    if (!self.associationCandidatesEnabled) {
        return;
    }

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
