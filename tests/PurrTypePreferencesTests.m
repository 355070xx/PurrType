#import <Cocoa/Cocoa.h>
#import "../src/PurrTypeEngine.h"
#import "../src/PurrTypeInputBehavior.h"
#import "../src/PurrTypePreferencesConstants.h"
#import "../src/PurrTypePreferencesWindowController.h"
#include <math.h>

static NSInteger const MKPreferencesTestShortcutTagSwitchInputMode = 9001;
static NSInteger const MKPreferencesTestShortcutTagPrivacyLock = 9002;
static NSInteger const MKPreferencesTestShortcutTagModeBase = 9100;
static CGFloat const MKPreferencesExpectedCoverAspectRatio = 1672.0 / 941.0;
static CGFloat const MKPreferencesExpectedCoverMaxWidth = 380.0;

static void AssertTrue(BOOL condition, NSString *message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        exit(1);
    }
}

@interface PreferencesTestDelegate : NSObject <PurrTypePreferencesWindowControllerDelegate>
@property(nonatomic, copy) NSString *mode;
@property(nonatomic, assign) BOOL learningEnabled;
@property(nonatomic, assign) BOOL privacyLockEnabled;
@property(nonatomic, assign) BOOL rawEnglishCandidateEnabled;
@property(nonatomic, assign) BOOL spacePagingEnabled;
@property(nonatomic, assign) NSUInteger candidatePageSize;
@property(nonatomic, copy) NSArray<NSString *> *enabledInputModes;
@property(nonatomic, copy) NSString *switchInputModeShortcut;
@property(nonatomic, copy) NSString *privacyLockShortcut;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *modeShortcutsByMode;
@property(nonatomic, assign) NSUInteger modeChangeCount;
@property(nonatomic, assign) NSUInteger privacyLockChangeCount;
@property(nonatomic, assign) NSUInteger privacyLockShortcutChangeCount;
@property(nonatomic, assign) NSUInteger switchInputModeShortcutChangeCount;
@property(nonatomic, assign) NSUInteger modeShortcutChangeCount;
@property(nonatomic, assign) NSUInteger rawEnglishChangeCount;
@property(nonatomic, assign) NSUInteger spacePagingChangeCount;
@property(nonatomic, assign) NSUInteger candidatePageSizeChangeCount;
@property(nonatomic, assign) NSUInteger enabledInputModesChangeCount;
@end

@implementation PreferencesTestDelegate

- (instancetype)init {
    self = [super init];
    if (self) {
        _mode = MKInputModeSucheng;
        _rawEnglishCandidateEnabled = YES;
        _spacePagingEnabled = YES;
        _candidatePageSize = 9;
        _enabledInputModes = [PurrTypeInputBehavior defaultEnabledInputModes];
        _switchInputModeShortcut = [PurrTypeInputBehavior defaultSwitchInputModeShortcutSpec];
        _privacyLockShortcut = @"double_backtick";
        _modeShortcutsByMode = [@{
            MKInputModeSucheng: @"ctrl_shift_1",
            MKInputModeSmartSucheng: @"ctrl_shift_2",
            MKInputModeCangjie: @"ctrl_shift_3",
            MKInputModePinyin: @"ctrl_shift_4"
        } mutableCopy];
    }
    return self;
}

- (NSString *)preferencesCurrentMode {
    return self.mode;
}

- (void)preferencesSwitchToMode:(NSString *)mode {
    self.mode = mode;
    self.modeChangeCount += 1;
}

- (BOOL)preferencesLearningEnabled {
    return self.learningEnabled;
}

- (void)preferencesSetLearningEnabled:(BOOL)enabled {
    self.learningEnabled = enabled;
}

- (BOOL)preferencesPrivacyLockEnabled {
    return self.privacyLockEnabled;
}

- (void)preferencesSetPrivacyLockEnabled:(BOOL)enabled {
    self.privacyLockEnabled = enabled;
    self.privacyLockChangeCount += 1;
}

- (BOOL)preferencesRawEnglishCandidateEnabled {
    return self.rawEnglishCandidateEnabled;
}

- (void)preferencesSetRawEnglishCandidateEnabled:(BOOL)enabled {
    self.rawEnglishCandidateEnabled = enabled;
    self.rawEnglishChangeCount += 1;
}

- (BOOL)preferencesSpacePagingEnabled {
    return self.spacePagingEnabled;
}

- (void)preferencesSetSpacePagingEnabled:(BOOL)enabled {
    self.spacePagingEnabled = enabled;
    self.spacePagingChangeCount += 1;
}

- (NSUInteger)preferencesCandidatePageSize {
    return self.candidatePageSize;
}

- (void)preferencesSetCandidatePageSize:(NSUInteger)pageSize {
    self.candidatePageSize = pageSize;
    self.candidatePageSizeChangeCount += 1;
}

- (NSArray<NSString *> *)preferencesEnabledInputModes {
    return self.enabledInputModes;
}

- (void)preferencesSetEnabledInputModes:(NSArray<NSString *> *)enabledInputModes {
    self.enabledInputModes = [PurrTypeInputBehavior normalizedEnabledInputModes:enabledInputModes];
    if (![self.enabledInputModes containsObject:self.mode]) {
        self.mode = self.enabledInputModes.firstObject ?: MKInputModeSucheng;
    }
    self.enabledInputModesChangeCount += 1;
}

- (NSString *)preferencesSwitchInputModeShortcut {
    return self.switchInputModeShortcut;
}

- (void)preferencesSetSwitchInputModeShortcut:(NSString *)shortcutSpec {
    self.switchInputModeShortcut = shortcutSpec;
    self.switchInputModeShortcutChangeCount += 1;
}

- (NSString *)preferencesPrivacyLockShortcut {
    return self.privacyLockShortcut;
}

- (void)preferencesSetPrivacyLockShortcut:(NSString *)shortcutSpec {
    self.privacyLockShortcut = shortcutSpec;
    self.privacyLockShortcutChangeCount += 1;
}

- (NSDictionary<NSString *, NSString *> *)preferencesModeShortcutsByMode {
    return self.modeShortcutsByMode;
}

- (void)preferencesSetModeShortcut:(NSString *)shortcutSpec forMode:(NSString *)mode {
    self.modeShortcutsByMode[mode] = shortcutSpec;
    self.modeShortcutChangeCount += 1;
}

- (void)preferencesResetLearning {
}

@end

static void CollectViewsOfClass(NSView *view, Class viewClass, NSMutableArray<NSView *> *results) {
    if ([view isKindOfClass:viewClass]) {
        [results addObject:view];
    }
    for (NSView *subview in view.subviews) {
        CollectViewsOfClass(subview, viewClass, results);
    }
}

static NSArray<NSView *> *ViewsOfClass(NSView *root, Class viewClass) {
    NSMutableArray<NSView *> *results = [NSMutableArray array];
    CollectViewsOfClass(root, viewClass, results);
    return results;
}

static NSArray<NSButton *> *SidebarButtons(NSView *root) {
    Class sidebarButtonClass = NSClassFromString(@"MKPreferencesSidebarButton");
    NSMutableArray<NSButton *> *buttons = [NSMutableArray array];
    for (NSView *view in ViewsOfClass(root, sidebarButtonClass)) {
        [buttons addObject:(NSButton *)view];
    }
    return buttons;
}

static NSScrollView *CurrentScrollView(NSView *root) {
    NSArray<NSView *> *scrollViews = ViewsOfClass(root, [NSScrollView class]);
    return scrollViews.count == 1 ? (NSScrollView *)scrollViews[0] : nil;
}

static Class PreferencesSwitchClass(void) {
    return NSClassFromString(@"MKPreferencesSwitchControl");
}

static Class PreferencesSegmentedControlClass(void) {
    return NSClassFromString(@"MKPreferencesSegmentedControl");
}

static Class PreferencesShortcutRecorderClass(void) {
    return NSClassFromString(@"MKPreferencesShortcutRecorderControl");
}

static NSArray<NSControl *> *EnabledSwitches(NSView *root) {
    NSMutableArray<NSControl *> *switches = [NSMutableArray array];
    for (NSView *view in ViewsOfClass(root, PreferencesSwitchClass())) {
        NSControl *toggle = (NSControl *)view;
        if (toggle.enabled) {
            [switches addObject:toggle];
        }
    }
    return switches;
}

static NSControl *FindSegmentedControl(NSView *root, NSArray<NSString *> *labels) {
    for (NSView *view in ViewsOfClass(root, PreferencesSegmentedControlClass())) {
        id control = (id)view;
        if ([[control valueForKey:@"segmentCount"] integerValue] != (NSInteger)labels.count) {
            continue;
        }

        BOOL matches = YES;
        for (NSUInteger index = 0; index < labels.count; index += 1) {
            if (![[control labelForSegment:(NSInteger)index] isEqualToString:labels[index]]) {
                matches = NO;
                break;
            }
        }
        if (matches) {
            return (NSControl *)view;
        }
    }
    return nil;
}

static void SelectSegmentAndSend(NSControl *control, NSInteger selectedSegment) {
    [control setValue:@(selectedSegment) forKey:@"selectedSegment"];
    [control sendAction:control.action to:control.target];
}

static void SetSwitchStateAndSend(NSControl *toggle, NSControlStateValue state) {
    [toggle setValue:@(state) forKey:@"state"];
    [toggle sendAction:toggle.action to:toggle.target];
}

static NSControl *FindShortcutRecorder(NSView *root, NSInteger tag) {
    for (NSView *view in ViewsOfClass(root, PreferencesShortcutRecorderClass())) {
        NSControl *recorder = (NSControl *)view;
        if (recorder.enabled && recorder.tag == tag) {
            return recorder;
        }
    }
    return nil;
}

static void SetShortcutAndSend(NSControl *recorder, NSString *shortcutSpec) {
    [recorder setValue:shortcutSpec forKey:@"shortcutSpec"];
    [recorder sendAction:recorder.action to:recorder.target];
}

static void RecordShortcutWithKey(NSControl *recorder, NSWindow *window, NSUInteger flags, NSInteger keyCode, NSString *characters) {
    NSPoint localPoint = NSMakePoint(4.0, 4.0);
    NSPoint windowPoint = [recorder convertPoint:localPoint toView:nil];
    NSEvent *mouseEvent = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown
                                             location:windowPoint
                                        modifierFlags:0
                                            timestamp:0
                                         windowNumber:window.windowNumber
                                              context:nil
                                          eventNumber:1
                                           clickCount:1
                                             pressure:1.0];
    [recorder mouseDown:mouseEvent];
    AssertTrue([[recorder valueForKey:@"recording"] boolValue], @"clicking shortcut recorder enters recording state");

    NSEvent *keyEvent = [NSEvent keyEventWithType:NSEventTypeKeyDown
                                         location:NSZeroPoint
                                    modifierFlags:flags
                                        timestamp:0
                                     windowNumber:window.windowNumber
                                          context:nil
                                       characters:characters
                      charactersIgnoringModifiers:characters
                                        isARepeat:NO
                                          keyCode:(unsigned short)keyCode];
    [recorder keyDown:keyEvent];
}

static NSButton *FindSidebarButton(NSView *root, NSString *title) {
    for (NSButton *button in SidebarButtons(root)) {
        if ([button.title isEqualToString:title]) {
            return button;
        }
    }
    return nil;
}

static NSButton *FindButton(NSView *root, NSString *title) {
    Class sidebarButtonClass = NSClassFromString(@"MKPreferencesSidebarButton");
    for (NSView *view in ViewsOfClass(root, [NSButton class])) {
        if ([view isKindOfClass:sidebarButtonClass]) {
            continue;
        }
        NSButton *button = (NSButton *)view;
        if ([button.title isEqualToString:title]) {
            return button;
        }
    }
    return nil;
}

static void SwitchToSidebarItem(NSView *root, NSString *title) {
    NSButton *button = FindSidebarButton(root, title);
    AssertTrue(button != nil, [NSString stringWithFormat:@"sidebar exposes %@", title]);
    [button sendAction:button.action to:button.target];
}

static BOOL CardsHaveUsableFrames(NSView *root) {
    Class cardClass = NSClassFromString(@"MKPreferencesCardView");
    NSArray<NSView *> *cards = ViewsOfClass(root, cardClass);
    if (cards.count == 0) {
        NSLog(@"No preference cards found");
        return NO;
    }

    for (NSView *card in cards) {
        if (NSWidth(card.frame) < 300 || NSHeight(card.frame) < 70) {
            NSLog(@"Preference card has unusable frame: %@", NSStringFromRect(card.frame));
            NSLog(@"Card superview frame: %@", NSStringFromRect(card.superview.frame));
            NSLog(@"Card document frame: %@", NSStringFromRect(card.enclosingScrollView.documentView.frame));
            return NO;
        }
    }
    return YES;
}

static BOOL RightPaneHasNoHorizontalOverflow(NSView *root) {
    NSArray<NSView *> *scrollViews = ViewsOfClass(root, [NSScrollView class]);
    if (scrollViews.count != 1) {
        NSLog(@"Expected one scroll view, found %@", @(scrollViews.count));
        return NO;
    }

    NSScrollView *scrollView = (NSScrollView *)scrollViews[0];
    CGFloat clipWidth = NSWidth(scrollView.contentView.bounds);
    if (clipWidth <= 0.0) {
        clipWidth = NSWidth(scrollView.bounds);
    }
    if (clipWidth <= 0.0) {
        clipWidth = MAX(0.0, NSWidth(root.bounds) - 150.0);
    }
    CGFloat documentWidth = NSWidth(scrollView.documentView.frame);
    if (documentWidth > clipWidth + 1.0) {
        NSLog(@"Document view overflows horizontally: clip=%@ document=%@",
              @(clipWidth),
              @(documentWidth));
        return NO;
    }

    Class cardClass = NSClassFromString(@"MKPreferencesCardView");
    for (NSView *card in ViewsOfClass(root, cardClass)) {
        NSRect frameInDocument = [card.superview convertRect:card.frame toView:scrollView.documentView];
        if (NSMinX(frameInDocument) < -1.0 || NSMaxX(frameInDocument) > documentWidth + 1.0) {
            NSLog(@"Card exceeds document width: card=%@ documentWidth=%@",
                  NSStringFromRect(frameInDocument),
                  @(documentWidth));
            return NO;
        }
    }
    return YES;
}

static BOOL CoverUsesArtworkAspectRatio(NSView *root) {
    Class coverClass = NSClassFromString(@"MKPreferencesCoverView");
    NSArray<NSView *> *covers = ViewsOfClass(root, coverClass);
    if (covers.count != 1) {
        NSLog(@"Expected one preference cover view, found %@", @(covers.count));
        return NO;
    }

    NSView *cover = covers[0];
    CGFloat width = NSWidth(cover.frame);
    CGFloat height = NSHeight(cover.frame);
    if (width <= 0.0 || height <= 0.0) {
        NSLog(@"Preference cover has empty frame: %@", NSStringFromRect(cover.frame));
        return NO;
    }

    CGFloat ratio = width / height;
    if (fabs(ratio - MKPreferencesExpectedCoverAspectRatio) > 0.02) {
        NSLog(@"Preference cover aspect ratio is %@, expected %@. Frame: %@",
              @(ratio),
              @(MKPreferencesExpectedCoverAspectRatio),
              NSStringFromRect(cover.frame));
        return NO;
    }

    if (width > MKPreferencesExpectedCoverMaxWidth + 1.0) {
        NSLog(@"Preference cover exceeds max visual width: %@", NSStringFromRect(cover.frame));
        return NO;
    }

    return YES;
}

static BOOL LabelWithTextHasMinimumHeight(NSView *root, NSString *text, CGFloat minimumHeight) {
    for (NSView *view in ViewsOfClass(root, [NSTextField class])) {
        NSTextField *label = (NSTextField *)view;
        if (![label.stringValue isEqualToString:text]) {
            continue;
        }

        if (NSHeight(label.frame) + 0.5 >= minimumHeight) {
            return YES;
        }

        NSLog(@"Label %@ is clipped-risk height: %@", text, NSStringFromRect(label.frame));
        return NO;
    }

    NSLog(@"Label not found: %@", text);
    return NO;
}

static BOOL SidebarLabelWithTextHasIntrinsicWidth(NSView *root, NSString *text) {
    NSScrollView *scrollView = CurrentScrollView(root);
    if (!scrollView) {
        NSLog(@"Sidebar width check needs the current scroll view");
        return NO;
    }

    NSRect scrollFrame = [scrollView.superview convertRect:scrollView.frame toView:root];
    CGFloat sidebarMaxX = NSMinX(scrollFrame);
    for (NSView *view in ViewsOfClass(root, [NSTextField class])) {
        NSTextField *label = (NSTextField *)view;
        if (![label.stringValue isEqualToString:text]) {
            continue;
        }

        NSRect frame = [label.superview convertRect:label.frame toView:root];
        if (NSMidX(frame) >= sidebarMaxX) {
            continue;
        }

        NSDictionary<NSAttributedStringKey, id> *attributes = @{
            NSFontAttributeName: label.font ?: [NSFont systemFontOfSize:[NSFont systemFontSize]]
        };
        CGFloat requiredWidth = ceil([label.stringValue sizeWithAttributes:attributes].width);
        if (NSWidth(label.frame) + 0.5 >= requiredWidth) {
            return YES;
        }

        NSLog(@"Sidebar label %@ is clipped-risk width: %@ required=%@",
              text,
              NSStringFromRect(label.frame),
              @(requiredWidth));
        return NO;
    }

    NSLog(@"Sidebar label not found: %@", text);
    return NO;
}

static NSImageView *FindImageViewWithAccessibilityLabel(NSView *root, NSString *label) {
    for (NSView *view in ViewsOfClass(root, [NSImageView class])) {
        NSImageView *imageView = (NSImageView *)view;
        if ([[imageView accessibilityLabel] isEqualToString:label]) {
            return imageView;
        }
    }
    return nil;
}

static NSRect FrameInView(NSView *view, NSView *root) {
    return [view.superview convertRect:view.frame toView:root];
}

static void FlushWindowLayout(NSWindow *window) {
    [window.contentView setNeedsLayout:YES];
    [window.contentView layoutSubtreeIfNeeded];
    [window displayIfNeeded];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    [window.contentView layoutSubtreeIfNeeded];
    for (NSView *view in ViewsOfClass(window.contentView, [NSScrollView class])) {
        NSScrollView *scrollView = (NSScrollView *)view;
        [scrollView.documentView setNeedsLayout:YES];
        [scrollView.documentView layoutSubtreeIfNeeded];
    }
}

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        [NSApplication sharedApplication];

        NSString *root = [[NSFileManager defaultManager] currentDirectoryPath];
        NSString *cangjieDirectory = [root stringByAppendingPathComponent:@"third_party/rime-cangjie"];
        NSString *pinyinPath = [root stringByAppendingPathComponent:@"resources/pinyin_seed.tsv"];
        NSString *learningPath = [NSTemporaryDirectory() stringByAppendingPathComponent:
            [NSString stringWithFormat:@"PurrTypePreferencesTests-%@.json", [NSUUID UUID].UUIDString]];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:MKUserDefaultsSuiteName] ?: [NSUserDefaults standardUserDefaults];
        [defaults setObject:@"zh-Hant" forKey:MKUserDefaultPreferencesLanguageKey];
        [defaults synchronize];
        PurrTypeEngine *engine = [[PurrTypeEngine alloc] initWithCangjieDirectory:cangjieDirectory
                                                                            pinyinPath:pinyinPath
                                                                          learningPath:learningPath];
        PreferencesTestDelegate *delegate = [[PreferencesTestDelegate alloc] init];
        PurrTypePreferencesWindowController *controller = [[PurrTypePreferencesWindowController alloc] init];
        [controller showWithEngine:engine delegate:delegate];
        FlushWindowLayout(controller.window);
        NSRect initialContentRect = [controller.window contentRectForFrameRect:controller.window.frame];
        CGFloat initialAspectRatio = NSWidth(initialContentRect) / NSHeight(initialContentRect);
        CGFloat minimumContentHeight = NSHeight([controller.window contentRectForFrameRect:
            NSMakeRect(0, 0, controller.window.minSize.width, controller.window.minSize.height)]);
        AssertTrue(NSWidth(initialContentRect) <= 570 &&
                   NSHeight(initialContentRect) >= minimumContentHeight &&
                   initialAspectRatio < 1.0,
                   @"preferences window opens in a compact portrait proportion");
        AssertTrue(controller.window.minSize.width <= 520 && controller.window.minSize.height >= 620,
                   @"preferences window keeps compact minimum portrait bounds");

        NSView *rootView = controller.window.contentView;
        AssertTrue([controller.window.title isEqualToString:@"PurrType 設定"], @"preferences window title is localized to Traditional Chinese");
        AssertTrue(SidebarLabelWithTextHasIntrinsicWidth(rootView, @"PurrType"), @"preferences sidebar brand name is fully visible");
        AssertTrue(SidebarButtons(rootView).count == 5, @"preferences window exposes exactly five sidebar items");
        AssertTrue(FindSidebarButton(rootView, @"一般") != nil, @"preferences sidebar exposes General");
        AssertTrue(FindSidebarButton(rootView, @"輸入模式") != nil, @"preferences sidebar exposes Input Modes");
        AssertTrue(FindSidebarButton(rootView, @"打字") != nil, @"preferences sidebar exposes Typing");
        AssertTrue(FindSidebarButton(rootView, @"私隱與學習") != nil, @"preferences sidebar exposes Privacy & Learning");
        AssertTrue(FindSidebarButton(rootView, @"關於") != nil, @"preferences sidebar exposes About");
        AssertTrue(FindSidebarButton(rootView, @"Candidates") == nil, @"preferences sidebar does not expose Candidates");
        AssertTrue(FindSidebarButton(rootView, @"Shortcuts") == nil, @"preferences sidebar does not expose Shortcuts");
        AssertTrue(FindSidebarButton(rootView, @"Appearance") == nil, @"preferences sidebar does not expose Appearance");
        AssertTrue([ViewsOfClass(rootView, [NSVisualEffectView class]) count] == 0, @"preferences sidebar avoids vibrancy so it stays readable in dark mode");
        AssertTrue([ViewsOfClass(rootView, [NSScrollView class]) count] == 1, @"General tab is scrollable by default");
        AssertTrue([ViewsOfClass(rootView, NSClassFromString(@"MKPreferencesCoverView")) count] == 1, @"General tab exposes one cover image view by default");
        AssertTrue(CoverUsesArtworkAspectRatio(rootView), @"General cover uses the full artwork aspect ratio");
        [controller.window setContentSize:NSMakeSize(900, 720)];
        FlushWindowLayout(controller.window);
        AssertTrue(CoverUsesArtworkAspectRatio(rootView), @"General cover remains capped and proportional in wider windows");
        [controller.window setContentSize:NSMakeSize(540, 720)];
        FlushWindowLayout(controller.window);
        AssertTrue([[FindSidebarButton(rootView, @"一般") valueForKey:@"selectedItem"] boolValue], @"preferences opens on General");
        AssertTrue(FindSegmentedControl(rootView, @[@"速成", @"新速成", @"倉頡", @"拼音"]) == nil,
                   @"General opens without mode settings");
        AssertTrue(FindButton(rootView, @"選擇輸入模式") == nil, @"General does not expose onboarding navigation");
        AssertTrue(FindButton(rootView, @"調整打字") == nil, @"General does not expose onboarding navigation");
        AssertTrue(FindButton(rootView, @"私隱與學習") == nil, @"General does not expose onboarding navigation");
        NSControl *languageControl = FindSegmentedControl(rootView, @[@"系統", @"English", @"繁體中文"]);
        AssertTrue(languageControl != nil, @"General exposes preferences language controls");
        AssertTrue([[languageControl valueForKey:@"selectedSegment"] integerValue] == 2,
                   @"Preferences language control reflects saved Traditional Chinese setting");
        NSArray<NSControl *> *generalEnabledSwitches = EnabledSwitches(rootView);
        AssertTrue(generalEnabledSwitches.count == 4, @"General exposes four real input-mode toggles");
        NSScrollView *generalToggleScrollView = CurrentScrollView(rootView);
        NSView *generalToggleDocumentView = generalToggleScrollView.documentView;
        [generalToggleScrollView.contentView scrollToPoint:NSMakePoint(0.0, 120.0)];
        [generalToggleScrollView reflectScrolledClipView:generalToggleScrollView.contentView];
        NSPoint generalScrollOriginBeforeToggle = generalToggleScrollView.contentView.bounds.origin;
        NSControl *pinyinToggle = generalEnabledSwitches[3];
        SetSwitchStateAndSend(pinyinToggle, NSControlStateValueOff);
        FlushWindowLayout(controller.window);
        AssertTrue(![delegate.enabledInputModes containsObject:MKInputModePinyin] &&
                   delegate.enabledInputModesChangeCount == 1,
                   @"General can disable Pinyin input mode");
        AssertTrue(LabelWithTextHasMinimumHeight(rootView, @"已更新啟用的輸入模式。", 16.0),
                   @"General enabled-mode status message is fully visible");
        AssertTrue(CurrentScrollView(rootView) == generalToggleScrollView &&
                   generalToggleScrollView.documentView == generalToggleDocumentView &&
                   fabs(generalToggleScrollView.contentView.bounds.origin.y - generalScrollOriginBeforeToggle.y) < 1.0,
                   @"General input-mode toggles do not rebuild or jump the scroll view");
        NSScrollView *generalOnlyScrollView = CurrentScrollView(rootView);
        NSView *generalDocumentView = generalOnlyScrollView.documentView;
        NSControl *switchShortcutRecorder = FindShortcutRecorder(rootView, MKPreferencesTestShortcutTagSwitchInputMode);
        AssertTrue(switchShortcutRecorder != nil, @"General exposes editable Switch Input Mode shortcut recorder");
        RecordShortcutWithKey(switchShortcutRecorder, controller.window, NSEventModifierFlagControl, 0, @"a");
        AssertTrue([delegate.switchInputModeShortcut isEqualToString:@"keycode:1:0"] &&
                   delegate.switchInputModeShortcutChangeCount == 1,
                   @"Switch Input Mode shortcut recorder captures a real key event and updates delegate");
        AssertTrue(![[switchShortcutRecorder valueForKey:@"recording"] boolValue], @"shortcut recorder exits recording state after capture");
        AssertTrue(CurrentScrollView(rootView) == generalOnlyScrollView &&
                   generalOnlyScrollView.documentView == generalDocumentView,
                   @"General shortcut changes do not rebuild the scroll view");
        NSControl *privacyShortcutRecorder = FindShortcutRecorder(rootView, MKPreferencesTestShortcutTagPrivacyLock);
        AssertTrue(privacyShortcutRecorder != nil, @"General exposes editable Pause Learning shortcut recorder");
        SetShortcutAndSend(privacyShortcutRecorder, @"keycode:1:0");
        AssertTrue([delegate.privacyLockShortcut isEqualToString:@"double_backtick"] &&
                   delegate.privacyLockShortcutChangeCount == 0,
                   @"duplicate shortcut conflicts are rejected without mutating delegate");
        SetShortcutAndSend(privacyShortcutRecorder, @"ctrl_shift_backtick");
        AssertTrue([delegate.privacyLockShortcut isEqualToString:@"ctrl_shift_backtick"] &&
                   delegate.privacyLockShortcutChangeCount == 1,
                   @"Pause Learning shortcut recorder updates delegate");
        NSButton *resetShortcutButton = FindButton(rootView, @"重設");
        AssertTrue(resetShortcutButton != nil, @"General exposes shortcut reset controls");
        AssertTrue(CardsHaveUsableFrames(rootView), @"General tab has visible card frames by default");
        AssertTrue(RightPaneHasNoHorizontalOverflow(rootView), @"General tab does not overflow horizontally by default");

        SwitchToSidebarItem(rootView, @"輸入模式");
        FlushWindowLayout(controller.window);
        AssertTrue([ViewsOfClass(rootView, NSClassFromString(@"MKPreferencesCoverView")) count] == 1, @"Input Modes tab exposes one cover image view");
        NSControl *modeControl = FindSegmentedControl(rootView, @[@"速成", @"新速成", @"倉頡", @"拼音"]);
        AssertTrue(modeControl != nil, @"Input Modes tab exposes default mode control");
        SelectSegmentAndSend(modeControl, 3);
        AssertTrue(![delegate.mode isEqualToString:MKInputModePinyin], @"default mode control refuses disabled Pinyin");
        SelectSegmentAndSend(modeControl, 1);
        AssertTrue([delegate.mode isEqualToString:MKInputModeSmartSucheng] && delegate.modeChangeCount == 1, @"mode segmented control updates delegate to New Sucheng");
        SwitchToSidebarItem(rootView, @"輸入模式");
        FlushWindowLayout(controller.window);
        NSControl *candidatePageSizeControl = FindSegmentedControl(rootView, @[@"5", @"9"]);
        AssertTrue(candidatePageSizeControl != nil, @"Input tab exposes candidate page-size control");
        NSScrollView *inputModesScrollView = CurrentScrollView(rootView);
        NSView *inputModesDocumentView = inputModesScrollView.documentView;
        SelectSegmentAndSend(candidatePageSizeControl, 0);
        AssertTrue(delegate.candidatePageSize == 5 && delegate.candidatePageSizeChangeCount == 1, @"candidate page-size control updates delegate");
        AssertTrue(CurrentScrollView(rootView) == inputModesScrollView &&
                   inputModesScrollView.documentView == inputModesDocumentView,
                   @"Input Modes setting changes do not rebuild the scroll view");
        NSControl *suchengShortcutRecorder = FindShortcutRecorder(rootView, MKPreferencesTestShortcutTagModeBase);
        AssertTrue(suchengShortcutRecorder != nil, @"Input Modes tab exposes editable direct mode shortcut recorder");
        AssertTrue(FindShortcutRecorder(rootView, MKPreferencesTestShortcutTagModeBase + 3) == nil,
                   @"disabled Pinyin direct shortcut recorder is inactive");
        SetShortcutAndSend(suchengShortcutRecorder, @"keycode:1:42");
        AssertTrue([delegate.modeShortcutsByMode[MKInputModeSucheng] isEqualToString:@"keycode:1:42"] &&
                   delegate.modeShortcutChangeCount == 1,
                   @"mode shortcut recorder updates delegate");
        AssertTrue([ViewsOfClass(rootView, [NSPopUpButton class]) count] == 0, @"Input Modes tab does not use preset-only shortcut popups");
        AssertTrue(CardsHaveUsableFrames(rootView), @"Input Modes tab has visible card frames");
        AssertTrue(RightPaneHasNoHorizontalOverflow(rootView), @"Input Modes tab does not overflow horizontally");

        SwitchToSidebarItem(rootView, @"打字");
        FlushWindowLayout(controller.window);
        NSControl *spaceControl = FindSegmentedControl(rootView, @[@"提交第一候選", @"候選翻頁"]);
        AssertTrue(spaceControl != nil, @"Typing tab exposes Space key behavior control");
        NSScrollView *typingScrollView = CurrentScrollView(rootView);
        NSView *typingDocumentView = typingScrollView.documentView;
        SelectSegmentAndSend(spaceControl, 0);
        AssertTrue(!delegate.spacePagingEnabled && delegate.spacePagingChangeCount == 1, @"Space key segmented control updates delegate");
        AssertTrue(CurrentScrollView(rootView) == typingScrollView &&
                   typingScrollView.documentView == typingDocumentView,
                   @"Typing setting changes do not rebuild the scroll view");
        NSArray<NSControl *> *typingEnabledSwitches = EnabledSwitches(rootView);
        AssertTrue(typingEnabledSwitches.count == 1, @"Typing tab only exposes one behavior-backed switch");
        NSControl *rawSwitch = typingEnabledSwitches[0];
        SetSwitchStateAndSend(rawSwitch, NSControlStateValueOff);
        AssertTrue(!delegate.rawEnglishCandidateEnabled && delegate.rawEnglishChangeCount == 1, @"raw-English candidate switch updates delegate");
        AssertTrue(LabelWithTextHasMinimumHeight(rootView, @"組字", 24.0), @"Typing tab keeps Composition title fully visible");
        AssertTrue(CardsHaveUsableFrames(rootView), @"Typing tab has visible card frames");
        AssertTrue(RightPaneHasNoHorizontalOverflow(rootView), @"Typing tab does not overflow horizontally");

        SwitchToSidebarItem(rootView, @"私隱與學習");
        FlushWindowLayout(controller.window);
        NSScrollView *privacyScrollView = CurrentScrollView(rootView);
        NSView *privacyDocumentView = privacyScrollView.documentView;
        NSArray<NSControl *> *privacyEnabledSwitches = EnabledSwitches(rootView);
        AssertTrue(privacyEnabledSwitches.count == 2, @"Privacy & Learning tab exposes learning and Privacy Lock switches");
        AssertTrue([ViewsOfClass(rootView, [NSPopUpButton class]) count] == 0, @"Privacy & Learning tab does not duplicate shortcut configuration");
        AssertTrue(FindButton(rootView, @"到一般設定編輯") != nil, @"Privacy & Learning links shortcut editing back to General");
        NSControl *learningSwitch = privacyEnabledSwitches[0];
        SetSwitchStateAndSend(learningSwitch, NSControlStateValueOn);
        AssertTrue(delegate.learningEnabled, @"learning switch updates delegate");
        NSControl *privacyLockSwitch = privacyEnabledSwitches[1];
        SetSwitchStateAndSend(privacyLockSwitch, NSControlStateValueOn);
        AssertTrue(delegate.privacyLockEnabled && delegate.privacyLockChangeCount == 1, @"Privacy Lock switch updates delegate");
        AssertTrue(CurrentScrollView(rootView) == privacyScrollView &&
                   privacyScrollView.documentView == privacyDocumentView,
                   @"Privacy & Learning setting changes do not rebuild the scroll view");
        AssertTrue([delegate.privacyLockShortcut isEqualToString:@"ctrl_shift_backtick"] &&
                   delegate.privacyLockShortcutChangeCount == 1,
                   @"Privacy tab shortcut reference does not mutate shortcut preferences");
        AssertTrue(LabelWithTextHasMinimumHeight(rootView, @"學習", 24.0), @"Privacy & Learning tab keeps Learning title fully visible");
        NSButton *privacyPolicyButton = FindButton(rootView, @"開啟私隱政策");
        AssertTrue(privacyPolicyButton != nil, @"Privacy & Learning exposes an in-app privacy policy button");
        [privacyPolicyButton sendAction:privacyPolicyButton.action to:privacyPolicyButton.target];
        FlushWindowLayout(controller.window.attachedSheet ?: controller.window);
        NSWindow *privacyPolicySheet = controller.window.attachedSheet;
        AssertTrue(privacyPolicySheet != nil, @"Privacy policy opens as an attached preferences sheet");
        NSArray<NSView *> *privacyPolicyTextViews = ViewsOfClass(privacyPolicySheet.contentView, [NSTextView class]);
        AssertTrue(privacyPolicyTextViews.count == 1, @"Privacy policy sheet contains one text view");
        NSTextView *privacyPolicyTextView = (NSTextView *)privacyPolicyTextViews[0];
        AssertTrue(!privacyPolicyTextView.editable && privacyPolicyTextView.selectable,
                   @"Privacy policy text is read-only and selectable");
        AssertTrue([privacyPolicyTextView.string containsString:@"PurrType Privacy Policy"],
                   @"Privacy policy sheet displays the bundled policy text");
        NSButton *closePrivacyPolicyButton = FindButton(privacyPolicySheet.contentView, @"關閉");
        AssertTrue(closePrivacyPolicyButton != nil, @"Privacy policy sheet exposes a close button");
        [closePrivacyPolicyButton sendAction:closePrivacyPolicyButton.action to:closePrivacyPolicyButton.target];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        AssertTrue(controller.window.attachedSheet == nil, @"Privacy policy sheet closes without leaving an attached modal");
        AssertTrue(CardsHaveUsableFrames(rootView), @"Privacy & Learning tab has visible card frames");
        AssertTrue(RightPaneHasNoHorizontalOverflow(rootView), @"Privacy & Learning tab does not overflow horizontally");

        SwitchToSidebarItem(rootView, @"關於");
        FlushWindowLayout(controller.window);
        NSButton *githubButton = FindButton(rootView, @"GitHub");
        NSButton *coffeeButton = FindButton(rootView, @"Buy Me a Coffee");
        NSButton *bugButton = FindButton(rootView, @"回報問題");
        AssertTrue(githubButton != nil && coffeeButton != nil && bugButton != nil, @"About links expose GitHub, Buy Me a Coffee, and Report a Bug buttons");
        NSRect githubFrame = FrameInView(githubButton, rootView);
        NSRect coffeeFrame = FrameInView(coffeeButton, rootView);
        NSRect bugFrame = FrameInView(bugButton, rootView);
        AssertTrue(fabs(NSMinY(githubFrame) - NSMinY(coffeeFrame)) < 2.0 &&
                   fabs(NSMinY(coffeeFrame) - NSMinY(bugFrame)) < 2.0,
                   @"About link buttons are arranged horizontally");
        NSImageView *coffeeQRCode = FindImageViewWithAccessibilityLabel(rootView, @"Buy Me a Coffee QR Code");
        AssertTrue(coffeeQRCode != nil && coffeeQRCode.image != nil, @"About links expose a Buy Me a Coffee QR code");
        NSRect qrFrame = FrameInView(coffeeQRCode, rootView);
        AssertTrue(!NSIntersectsRect(qrFrame, coffeeFrame),
                   @"Buy Me a Coffee QR code is separated from the horizontal button row");
        NSRect linksCardFrame = FrameInView(coffeeQRCode.superview, rootView);
        AssertTrue(fabs(NSMidX(qrFrame) - NSMidX(linksCardFrame)) < 2.0,
                   @"Buy Me a Coffee QR code is centered in the Links card");
        AssertTrue([ViewsOfClass(rootView, [NSButton class]) count] >= 3, @"About tab exposes link buttons");
        AssertTrue(CardsHaveUsableFrames(rootView), @"About tab has visible card frames");
        AssertTrue(RightPaneHasNoHorizontalOverflow(rootView), @"About tab does not overflow horizontally");

        [controller.window setContentSize:NSMakeSize(520, 620)];
        for (NSString *tabTitle in @[@"一般", @"輸入模式", @"打字", @"私隱與學習", @"關於"]) {
            SwitchToSidebarItem(rootView, tabTitle);
            FlushWindowLayout(controller.window);
            AssertTrue(CardsHaveUsableFrames(rootView), [NSString stringWithFormat:@"%@ tab has usable card frames at minimum size", tabTitle]);
            AssertTrue(CoverUsesArtworkAspectRatio(rootView), [NSString stringWithFormat:@"%@ tab cover keeps full artwork aspect ratio at minimum size", tabTitle]);
            AssertTrue(RightPaneHasNoHorizontalOverflow(rootView), [NSString stringWithFormat:@"%@ tab does not overflow horizontally at minimum size", tabTitle]);
        }

        [controller close];
        [defaults removeObjectForKey:MKUserDefaultPreferencesLanguageKey];
        [defaults synchronize];
        [[NSFileManager defaultManager] removeItemAtPath:learningPath error:nil];
        NSLog(@"PASS: PurrTypePreferencesTests");
    }

    return 0;
}
