#import <Cocoa/Cocoa.h>
#import "PurrTypePreferencesStore.h"
#import "PurrTypePreferencesWindowController.h"

@interface PurrTypePreferencesAppDelegate : NSObject <NSApplicationDelegate, PurrTypePreferencesWindowControllerDelegate>

@property(nonatomic, strong) PurrTypePreferencesStore *preferencesStore;

- (void)installApplicationMenu;
- (void)showPreferencesWindow;

@end

@implementation PurrTypePreferencesAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    self.preferencesStore = [PurrTypePreferencesStore sharedStore];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    [self installApplicationMenu];
    [self showPreferencesWindow];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    (void)sender;
    return YES;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    (void)sender;
    (void)flag;
    [self showPreferencesWindow];
    return YES;
}

- (void)installApplicationMenu {
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@""];

    NSMenuItem *appMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [mainMenu addItem:appMenuItem];

    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"PurrType", nil)];
    NSString *showTitle = NSLocalizedString(@"Show PurrType Preferences", nil);
    NSMenuItem *showItem = [[NSMenuItem alloc] initWithTitle:showTitle
                                                      action:@selector(showPreferencesWindow)
                                               keyEquivalent:@","];
    showItem.target = self;
    showItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [appMenu addItem:showItem];
    [appMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *closeItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Close Window", nil)
                                                       action:@selector(performClose:)
                                                keyEquivalent:@"w"];
    closeItem.target = nil;
    closeItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [appMenu addItem:closeItem];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Quit PurrType Preferences", nil)
                                                      action:@selector(terminate:)
                                               keyEquivalent:@"q"];
    quitItem.target = NSApp;
    quitItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [appMenu addItem:quitItem];

    appMenuItem.submenu = appMenu;

    NSMenuItem *editMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Edit", nil) action:nil keyEquivalent:@""];
    [mainMenu addItem:editMenuItem];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Edit", nil)];
    NSMenuItem *undoItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Undo", nil)
                                                      action:@selector(undo:)
                                               keyEquivalent:@"z"];
    undoItem.target = nil;
    undoItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [editMenu addItem:undoItem];
    NSMenuItem *redoItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Redo", nil)
                                                      action:@selector(redo:)
                                               keyEquivalent:@"z"];
    redoItem.target = nil;
    redoItem.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [editMenu addItem:redoItem];
    [editMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *cutItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Cut", nil)
                                                     action:@selector(cut:)
                                              keyEquivalent:@"x"];
    cutItem.target = nil;
    cutItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [editMenu addItem:cutItem];
    NSMenuItem *copyItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy", nil)
                                                      action:@selector(copy:)
                                               keyEquivalent:@"c"];
    copyItem.target = nil;
    copyItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [editMenu addItem:copyItem];
    NSMenuItem *pasteItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Paste", nil)
                                                       action:@selector(paste:)
                                                keyEquivalent:@"v"];
    pasteItem.target = nil;
    pasteItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [editMenu addItem:pasteItem];
    [editMenu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *selectAllItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Select All", nil)
                                                           action:@selector(selectAll:)
                                                    keyEquivalent:@"a"];
    selectAllItem.target = nil;
    selectAllItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [editMenu addItem:selectAllItem];
    editMenuItem.submenu = editMenu;

    NSMenuItem *windowMenuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Window", nil) action:nil keyEquivalent:@""];
    [mainMenu addItem:windowMenuItem];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Window", nil)];
    NSMenuItem *minimizeItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Minimize", nil)
                                                          action:@selector(performMiniaturize:)
                                                   keyEquivalent:@"m"];
    minimizeItem.target = nil;
    minimizeItem.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [windowMenu addItem:minimizeItem];
    NSMenuItem *bringAllToFrontItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Bring All to Front", nil)
                                                                 action:@selector(arrangeInFront:)
                                                          keyEquivalent:@""];
    bringAllToFrontItem.target = nil;
    [windowMenu addItem:bringAllToFrontItem];
    windowMenuItem.submenu = windowMenu;
    [NSApp setWindowsMenu:windowMenu];

    NSApp.mainMenu = mainMenu;
}

- (void)showPreferencesWindow {
    [[PurrTypePreferencesWindowController sharedController] showWithEngine:nil delegate:self];
}

- (NSString *)preferencesCurrentMode {
    return [self.preferencesStore engineMode];
}

- (void)preferencesSwitchToMode:(NSString *)mode {
    if (mode.length == 0 || ![self.preferencesStore isEngineModeEnabled:mode]) {
        return;
    }
    [self.preferencesStore setEngineMode:mode];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (BOOL)preferencesLearningEnabled {
    return [self.preferencesStore learningEnabled];
}

- (void)preferencesSetLearningEnabled:(BOOL)enabled {
    [self.preferencesStore setLearningEnabled:enabled];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (BOOL)preferencesPrivacyLockEnabled {
    return [self.preferencesStore privacyLockEnabled];
}

- (void)preferencesSetPrivacyLockEnabled:(BOOL)enabled {
    [self.preferencesStore setPrivacyLockEnabled:enabled];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (BOOL)preferencesRawEnglishCandidateEnabled {
    return [self.preferencesStore rawEnglishCandidateEnabled];
}

- (void)preferencesSetRawEnglishCandidateEnabled:(BOOL)enabled {
    [self.preferencesStore setRawEnglishCandidateEnabled:enabled];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (NSString *)preferencesRawEnglishCandidatePosition {
    return [self.preferencesStore rawEnglishCandidatePosition];
}

- (void)preferencesSetRawEnglishCandidatePosition:(NSString *)position {
    [self.preferencesStore setRawEnglishCandidatePosition:position];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (BOOL)preferencesSpellingSuggestionsEnabled {
    return [self.preferencesStore spellingSuggestionsEnabled];
}

- (void)preferencesSetSpellingSuggestionsEnabled:(BOOL)enabled {
    [self.preferencesStore setSpellingSuggestionsEnabled:enabled];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (BOOL)preferencesSpacePagingEnabled {
    return [self.preferencesStore spacePagingEnabled];
}

- (void)preferencesSetSpacePagingEnabled:(BOOL)enabled {
    [self.preferencesStore setSpacePagingEnabled:enabled];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (BOOL)preferencesDecimalPointShortcutEnabled {
    return [self.preferencesStore decimalPointShortcutEnabled];
}

- (void)preferencesSetDecimalPointShortcutEnabled:(BOOL)enabled {
    [self.preferencesStore setDecimalPointShortcutEnabled:enabled];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (BOOL)preferencesChineseContextPunctuationEnabled {
    return [self.preferencesStore chineseContextPunctuationEnabled];
}

- (void)preferencesSetChineseContextPunctuationEnabled:(BOOL)enabled {
    [self.preferencesStore setChineseContextPunctuationEnabled:enabled];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (NSUInteger)preferencesCandidatePageSize {
    return [self.preferencesStore candidatePageSize];
}

- (void)preferencesSetCandidatePageSize:(NSUInteger)pageSize {
    [self.preferencesStore setCandidatePageSize:pageSize];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (NSString *)preferencesCandidatePanelOrientation {
    return [self.preferencesStore candidatePanelOrientation];
}

- (void)preferencesSetCandidatePanelOrientation:(NSString *)orientation {
    [self.preferencesStore setCandidatePanelOrientation:orientation];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (CGFloat)preferencesCandidatePanelFontSize {
    return [self.preferencesStore candidatePanelFontSize];
}

- (void)preferencesSetCandidatePanelFontSize:(CGFloat)fontSize {
    [self.preferencesStore setCandidatePanelFontSize:fontSize];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (NSString *)preferencesCandidatePanelHighlightColor {
    return [self.preferencesStore candidatePanelHighlightColor];
}

- (void)preferencesSetCandidatePanelHighlightColor:(NSString *)highlightColor {
    [self.preferencesStore setCandidatePanelHighlightColor:highlightColor];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (BOOL)preferencesAssociationCandidatesEnabled {
    return [self.preferencesStore associationCandidatesEnabled];
}

- (void)preferencesSetAssociationCandidatesEnabled:(BOOL)enabled {
    [self.preferencesStore setAssociationCandidatesEnabled:enabled];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (BOOL)preferencesAssociationContinuationEnabled {
    return [self.preferencesStore associationContinuationEnabled];
}

- (void)preferencesSetAssociationContinuationEnabled:(BOOL)enabled {
    [self.preferencesStore setAssociationContinuationEnabled:enabled];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (NSUInteger)preferencesCandidatePageSizeOverrideForMode:(NSString *)mode {
    return [self.preferencesStore candidatePageSizeOverrideForMode:mode];
}

- (void)preferencesSetCandidatePageSizeOverride:(NSUInteger)pageSize forMode:(NSString *)mode {
    [self.preferencesStore setCandidatePageSizeOverride:pageSize forMode:mode];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (NSString *)preferencesSpaceKeyOverrideForMode:(NSString *)mode {
    return [self.preferencesStore spaceKeyOverrideForMode:mode];
}

- (void)preferencesSetSpaceKeyOverride:(NSString *)overrideValue forMode:(NSString *)mode {
    [self.preferencesStore setSpaceKeyOverride:overrideValue forMode:mode];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (BOOL)preferencesClearReadingOnCompositionFailureEnabledForMode:(NSString *)mode {
    return [self.preferencesStore clearReadingOnCompositionFailureEnabledForMode:mode];
}

- (void)preferencesSetClearReadingOnCompositionFailureEnabled:(BOOL)enabled forMode:(NSString *)mode {
    [self.preferencesStore setClearReadingOnCompositionFailureEnabled:enabled forMode:mode];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (void)preferencesResetOverridesForMode:(NSString *)mode {
    [self.preferencesStore resetOverridesForMode:mode];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (NSArray<NSString *> *)preferencesEnabledInputModes {
    return [self.preferencesStore enabledInputModes];
}

- (void)preferencesSetEnabledInputModes:(NSArray<NSString *> *)enabledInputModes {
    [self.preferencesStore setEnabledInputModes:enabledInputModes];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (NSString *)preferencesSwitchInputModeShortcut {
    return [self.preferencesStore switchInputModeShortcut];
}

- (void)preferencesSetSwitchInputModeShortcut:(NSString *)shortcutSpec {
    [self.preferencesStore setSwitchInputModeShortcut:shortcutSpec];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (NSString *)preferencesPrivacyLockShortcut {
    return [self.preferencesStore privacyLockShortcut];
}

- (void)preferencesSetPrivacyLockShortcut:(NSString *)shortcutSpec {
    [self.preferencesStore setPrivacyLockShortcut:shortcutSpec];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (NSString *)preferencesVoiceRecognitionLocaleIdentifier {
    return [self.preferencesStore voiceRecognitionLocaleIdentifier];
}

- (void)preferencesSetVoiceRecognitionLocaleIdentifier:(NSString *)localeIdentifier {
    [self.preferencesStore setVoiceRecognitionLocaleIdentifier:localeIdentifier];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (BOOL)preferencesVoiceFloatingButtonVisible {
    return [self.preferencesStore voiceFloatingButtonVisible];
}

- (void)preferencesSetVoiceFloatingButtonVisible:(BOOL)visible {
    [self.preferencesStore setVoiceFloatingButtonVisible:visible];
    [self.preferencesStore postPreferencesChangedNotification];
}

- (NSDictionary<NSString *, NSString *> *)preferencesModeShortcutsByMode {
    return [self.preferencesStore modeShortcutsByMode];
}

- (void)preferencesSetModeShortcut:(NSString *)shortcutSpec forMode:(NSString *)mode {
    if ([self.preferencesStore setModeShortcut:shortcutSpec forMode:mode]) {
        [self.preferencesStore postPreferencesChangedNotification];
    }
}

- (void)preferencesResetLearning {
    [self.preferencesStore requestLearningReset];
}

@end

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        PurrTypePreferencesAppDelegate *delegate = [[PurrTypePreferencesAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
